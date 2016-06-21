require_relative 'base_stacker'

class Restacker < BaseStacker
  def initialize(options)
    super(options)
    @instance_timestamp = Time.now().strftime("%Y%m%d")
    @stack_timestamp = Time.now().strftime("%Y%m%d-%H%M")
  end

  # ensures template JSON is properly formated
  def load_template(template_file_path)
    begin
      template_body = open(template_file_path, 'r').read
      @cf.validate_template(template_body: template_body)
      return template_body
    rescue Aws::CloudFormation::Errors::ValidationError => e
      puts e.message
    end
    nil
  end

  def create_stack(template, stack_name, parameters)
    begin
      stack_id = @cf.create_stack(
        template_body: template,
        stack_name: stack_name,
        parameters: parameters,
        disable_rollback: true).stack_id
      puts "Creating stack #{stack_name} (#{stack_id})"

      stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
      while stack and stack.stack_status == CREATE_IN_PROGRESS
        sleep 30
        stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
        puts stack.stack_status
      end

      if stack.stack_status == CREATE_COMPLETE
        output = stack.outputs.pop
        if output
          return output.output_value
        end
      else
        puts "Stack creation failed (#{stack.stack_status})"
      end
    rescue Aws::CloudFormation::Errors::ServiceError => e
      puts e.message
    end
  end

  def delete_stack(stack_name)
    begin
      puts "Deleting stack #{stack_name}"
      resp = @cf.describe_stacks(stack_name: stack_name)
      stack_id = resp.stacks.pop.stack_id
      @cf.delete_stack(stack_name: stack_name)
      stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
      while stack and stack.stack_status == DELETE_IN_PROGRESS
        sleep 30
        stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
        puts stack.stack_status
      end
      puts "Stack #{stack_name} deleted: #{stack_id}"
    rescue Aws::CloudFormation::Errors::ValidationError => e
      puts e.message
    end
  end


  def list_stacks
    resp = @cf.list_stacks
    stacks = resp.stack_summaries.select {|stack| stack.stack_status != DELETE_COMPLETE }
    stacks.each {|stack| puts "#{stack.stack_status}: #{stack.stack_name}"}
  end

  def print_events(events)
    puts "Events:"
    puts "Date\t\t\tStatus\t\t\tType\t\t\tReason"
    events.each do |event|
      puts "#{event.timestamp} #{event.resource_status}\t#{event.resource_type}\t#{event.resource_status_reason}"
    end
  end

  def print_resources(resources)
    puts "Resources:"
    resources.each do |resource|
      puts "#{resource.resource_status} #{resource.physical_resource_id}"
    end
  end

  def print_desc(stack)
    puts "\nName: #{stack.stack_name}"
    puts "ID: #{stack.stack_id}"
    puts "Description: #{stack.description}"
    puts "Creation Time: #{stack.creation_time}"
    puts "Status: #{stack.stack_status}"

    if not stack.tags.empty?
      puts "\nTags:"
      stack.tags.each {|tag| puts "\t#{tag[:key]}:\t#{tag[:value]}" }
    end

    puts "\nParameters:" unless stack.parameters.empty?
    stack.parameters.each do |param|
      puts "\t#{param.parameter_key}:\t#{param.parameter_value}"
    end

    puts "\nOutputs:" unless stack.outputs.empty?
    stack.outputs.each do |out|
      puts "\t#{out.output_key}: #{out.output_value}\t -- #{out.description}"
    end
  end

  def describe_stack(stack_name)
    begin
      @cf.describe_stacks(stack_name: stack_name).stacks.each do |stack|
        if stack.stack_status != DELETE_COMPLETE
          print_desc(stack)
          if @options[:verbose]
            puts "\n"
            print_events(@cf.describe_stack_events(stack_name: stack.stack_id).stack_events)
            puts "\n"
            print_resources(@cf.describe_stack_resources(stack_name: stack.stack_id).stack_resources)
            puts "\n"
          end
        end
      end
    rescue Aws::CloudFormation::Errors::ValidationError => e
      puts e.message
    end
  end

  # Generates a sane ELB name
  def get_lb_name(plane, service_name)
    rand_chars = [*('A'..'Z')].sample(8).join
    "#{plane[0..2]}-#{service_name[0..18]}-#{rand_chars}"[0..31]
  end

  def translate(type, value)
    ec2 = Aws::EC2::Client.new(region: @options.fetch(:region), credentials: @creds)
    case type
    when :subnet
      filters = [{ name: 'tag-key', values: ['Name'] },
                 { name: 'tag-value', values: [value] }]
      subnets = ec2.describe_subnets(filters: filters).subnets
      value = subnets.first.subnet_id
    when :sgroups
      groups_ids = []
      value.split(',').each do |group|
        filters = [{ name: 'group-name', values: [group.strip] }]
        groups = ec2.describe_security_groups(filters: filters).security_groups
        groups_ids << groups.first.group_id
      end
      value = groups_ids.join(',')
    when :vpc
      filters = [{ name: 'tag-key', values: ['Name'] },
                 { name: 'tag-value', values: [value] }]
      value = ec2.describe_vpcs(filters: filters).vpcs.first.vpc_id
    end
    value
  end

  # Transforms template parameters (JSON parsed) to the
  # Aws::CloudFormation::Client expected format parameters:
  # [{ parameter_key: "Key", parameter_value: "Value"},...]
  def get_params(template_params)
    params_options = @options.fetch(:params, "").split(',')
    # the parameters passed by -p (inline params)
    params = {}
    params_options.each do |param|
      key, value = param.split('=')
      params[key] = value
    end

    # the parameters passed by -P (file)
    if @options.include?(:params_file)
      params = YAML.load(File.read(@options[:params_file])).merge(params)
    end

    # set the load balancer name if template includes the parameter
    if template_params.include?('LoadBalancerName')
      params['LoadBalancerName'] = get_lb_name(params['ServicePlane'], params['ServiceName'])
    end

    # merge the params
    params.map do |key, value|
      begin # replace named parameters
        if key =~ /.*Subnet\d/ && !value.start_with?('subnet-')
          value = translate(:subnet, value)
        end
        if key =~ /.*SecurityGroups/ && !value.start_with?('sg-')
          value = translate(:sgroups, value)
        end
        if key =~ /VpcId/ && !value.start_with?('vpc-')
          value = translate(:vpc, value)
        end
      rescue => e
        puts "Cound not translate #{key}: #{value} (#{e.message})"
      end
      { parameter_key: key, parameter_value: value }
    end
  end

  # Merges the template parameters with the stack parametes and returns the
  # Aws::CloudFormation::Client expected formated parameters object:
  # [{ parameter_key: "Key", parameter_value: "Value"},...]
  def get_merged_params(template_params, stack_params=[])
    overwire_params = get_params(template_params)

    overwire_params.push(
        {parameter_key: 'EnvironmentParameters', parameter_value: @options[:env_params]}
      ) if @options[:env_params]

    overwire_params.push(
        {parameter_key: 'StackCreator', parameter_value: @options[:username]}
      ) if @options[:username]

    # overwrite current stack params
    stack_params.each do |sparam|
      oparam = overwire_params.bsearch {|oparam| oparam[:parameter_key] == sparam[:parameter_key]}
      if oparam
        puts "Overwriting: #{sparam[:parameter_key]}: before: #{sparam[:parameter_value]}, after: #{oparam[:parameter_value]}"
        sparam[:parameter_value] = oparam[:parameter_value]
        overwire_params.delete(oparam)
      end
      puts "\t#{sparam[:parameter_key]}: \t#{sparam[:parameter_value]}"
    end

    # add remaining params to stack params
    stack_params.concat(overwire_params)
    stack_params.push(
      {parameter_key: 'TimeStamp', parameter_value: @instance_timestamp}
    )
    stack_params
  end

  def restack_by_id(stack_id, name, template=nil)
    puts "Restacking #{stack_id}"
  end

  def get_stack_name(current_name)
    name = @options.fetch(:name, current_name)
    r = /.*(\d{8}-\d{4})/
    if name =~ r
      name.gsub(r) {|m| m.gsub($1, @stack_timestamp)}
    else
      "#{name}-#{@stack_timestamp}"
    end
  end

  def restack_by_name(current_stack_name)
    puts "Restacking #{current_stack_name}"
    stack = @cf.describe_stacks(stack_name: current_stack_name).stacks.pop
    new_name = get_stack_name(current_stack_name)
    puts "Restacking #{stack.stack_name}, #{stack.stack_status}, new name: #{new_name}"

    # get the template body
    if @options[:template].nil?
      template = @cf.get_template(stack_name: current_stack_name).template_body
    else
      template = load_template(template)
    end
    template_param_keys = JSON.parse(template)['Parameters'].keys
    params = get_merged_params(template_param_keys, stack.parameters)
    create_stack(template_body, new_name, params)
  end

  def deploy_stack(template, name)
    template = load_template(@options[:template])
    name = get_stack_name(@options[:name])
    template_param_keys = JSON.parse(template)['Parameters'].keys
    create_stack(template, name, get_merged_params(template_param_keys))
  end

  def self.dump_stack_params(options)
    begin
      template = JSON.parse(File.open(options[:template]).read)
      params = {}
      template["Parameters"].each do |key, value|
        params[key] = value['Default']
      end
      puts params.to_yaml
    rescue JSON::ParserError => e
      puts "Error parsing #{options[:template]}"
      if options[:verbose]
        $stderr.puts e.message
      else
        $stderr.puts e.message.each_line.first
      end
    end
  end
end
