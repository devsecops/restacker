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

      printf "%-30s : %s\n", Rainbow("CREATING STACK").white.underline, stack_name
      printf "%-30s : %s\n", Rainbow("STACK ID").white.underline, stack_id

      stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
      while stack and stack.stack_status == STATUS[:CIP]
        sleep 30
        stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
        puts stack.stack_status
      end

      if stack.stack_status == STATUS[:CC]
        output = stack.outputs.pop
        if output
          return Rainbow("#{output.output_value}").green
        end
      else
        printf "%-30s : %s\n", Rainbow("CREATE_FAILED").red, stack.stack_status
      end
    rescue Aws::CloudFormation::Errors::ServiceError => e
      puts e.message
    end
  end

  def delete_stack(stack_name)
    begin
      resp = @cf.describe_stacks(stack_name: stack_name)
      stack_id = resp.stacks.pop.stack_id
      @cf.delete_stack(stack_name: stack_name)
      stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
      while stack and stack.stack_status == STATUS[:DIP]
        sleep 30
        stack = @cf.describe_stacks(stack_name: stack_id).stacks.pop
        puts Rainbow(stack.stack_status).white
      end
      printf "%-30s : %s\n", Rainbow("STACK DELETED").green, stack_name
      printf "%-30s : %s\n", Rainbow("STACK ID").green, stack_id
    rescue Aws::CloudFormation::Errors::ValidationError => e
      puts e.message
    end
  end


  def list_stacks
    resp = @cf.list_stacks.stack_summaries
    stacks = resp.select {|stack| stack.stack_status != STATUS[:DC] }
    stacks.each do |stack|
      if stack.stack_status.match(STATUS[:CF])
        printf("%-30s : %s\n", Rainbow(stack.stack_status).red, stack.stack_name)
      elsif stack.stack_status.match(STATUS[:CC])
        printf("%-30s : %s\n", Rainbow(stack.stack_status).green, stack.stack_name)
      elsif stack.stack_status.match(STATUS[:UC])
        printf("%-30s : %s\n", Rainbow(stack.stack_status).blue, stack.stack_name)
      end
    end
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
    printf "%-30s : %s\n", Rainbow("Name").white, stack.stack_name
    printf "%-30s : %s\n", Rainbow("ID").white, stack.stack_id
    printf "%-30s : %s\n", Rainbow("Description").white, stack.description
    printf "%-30s : %s\n", Rainbow("Creation Time").white, stack.creation_time
    printf "%-30s : %s\n", Rainbow("Status").white, stack.stack_status

    if not stack.tags.empty?
      printf "%-30s :\n", Rainbow("Tags").white
      stack.tags.each do |tag|
        printf "\t%-30s : %s\n", Rainbow(tag[:key]).white, tag[:value]
      end
    end

    if not stack.parameters.empty?
      printf "%-30s :\n", Rainbow("Parameters").white
      stack.parameters.each do |param|
        printf "\t%-40s : %s\n", Rainbow(param.parameter_key).white, param.parameter_value
      end
    end

    if not stack.outputs.empty?
      printf "%-30s :\n", Rainbow("Outputs").white
      stack.outputs.each do |out|
        printf "\t%-30s : %30s -- %s\n", Rainbow(out.output_key).white, out.output_value, out.description
      end
    end
  end

  def describe_stack(stack_name)
    begin
      @cf.describe_stacks(stack_name: stack_name).stacks.each do |stack|
        if stack.stack_status != STATUS[:DC]
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
        $stderr.puts "WARNING: No default parameter set for #{key}." if value['Default'] == nil
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

  def self.amis
    puts RestackerConfig.latest_amis
    # puts RestackerConfig.latest_amis("rhel6")
  end
end
