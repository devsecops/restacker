class RestackerConfig
  def self.load_config(plane)
    plane = get_plane if plane.nil?
    config = find_config
    if config[plane].nil?
      puts "Plane not found (#{plane}). Please see #{CONFIG_FILE}."
      exit
    end
    config[plane]
  end

  def self.get_plane(options)
    if options[:location]
      plane = options[:location]
    else
      plane = find_default_plane()
    end
    plane.to_sym
  end

  def self.configure(location)
    config = find_config()
    puts Rainbow("Configuration file location:").white.bright +  " #{CONFIG_FILE}"

    target = config.fetch(location, {}).fetch(:target)
    new_account_number, new_role_name, new_role_prefix = ""
    old_account_number = target[:account_number].to_s

    print Rainbow("Label [\"#{target[:label]}\"]:").white.bright
    new_label = gets.chomp

    loop do
      print Rainbow("Account Number [#{old_account_number}]:").white.bright

      new_account_number = gets.chomp
      break if (new_account_number =~ /\d{12,}/ || new_account_number.empty?)
    end

    loop do
      print Rainbow("Role Name [#{target[:role_name]}]:").white.bright
      new_role_name = gets.chomp
      break if (new_role_name =~ /[\w&&\S\-]/ || new_role_name.empty?)
    end

    loop do
      print Rainbow("Role Prefix [#{target[:role_prefix]}]:").white.bright
      new_role_prefix = gets.chomp
      break if (new_role_prefix =~ /[\w&&\S\-\/]/ || new_role_prefix.empty?)
    end

    target[:label] = new_label.empty? ? target[:label] : new_label
    target[:account_number] = new_account_number.empty? ? target[:account_number] : new_account_number
    target[:role_name] = new_role_name.empty? ? target[:role_name] : new_role_name
    target[:role_prefix] = new_role_prefix.empty? ? target[:role_prefix] : new_role_prefix

    File.open(CONFIG_FILE, 'w') do |f|
      f.write config.to_yaml
    end
  end

  def self.latest_amis(rhel=nil)
    latest_amis = YAML.load(get_object(find_config[:ctrl][:bucket][:ami_key]))
    if rhel
      return latest_amis[rhel]
    end
    latest_amis
  end

  private
  def self.find_config
    Dir.mkdir(CONFIG_DIR) unless Dir.exist?(CONFIG_DIR)
    begin
      if File.exist?(CONFIG_FILE)
        config = YAML.load_file(CONFIG_FILE)
      else
        config = YAML.load_file(SAMPLE_FILE)
        File.open(CONFIG_FILE, 'w') { |f| f.write config.to_yaml }
      end
    rescue Psych::SyntaxError
      raise "Improperly formatted YAML file: #{CONFIG_FILE}."
    rescue => e
      puts e.message
    end
    config
  end

  def self.find_default_plane
    find_config[:default][:label] || raise(Rainbow("Location was not provided and no default location was found in #{CONFIG_FILE}.").red)
  end

  def self.bucket
    find_config[:ctrl][:bucket][:name]
  end

  def self.prefix
    find_config[:ctrl][:bucket][:prefix] if find_config[:ctrl][:prefix]
  end

  def self.list_objects
    s3 = Aws::S3::Client.new
    keys = s3.list_objects(bucket: bucket, prefix: prefix).contents.map(&:key)
  end

  def self.get_object(key_input)
    s3 = Aws::S3::Client.new
    keys = s3.list_objects(bucket: bucket, prefix: prefix).contents.map(&:key)
    key = keys.select { |key| key.match(key_input) }.first.to_s
    s3.get_object(bucket: bucket, key: key).body.read
  end
end
