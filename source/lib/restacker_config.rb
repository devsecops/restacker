class RestackerConfig
  def self.load_config(plane)
    plane = get_plane if plane.nil?
    config = find_config
    # puts "Inside 'self.load_config'"
    # puts "Config: #{config}"
    # puts "Plane: #{plane}"
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
    # puts "Inside 'self.find_default_plane'"
    config = find_config()
    # puts "config: #{config}"
    if config[:default][:label]
      config[:default][:label].to_sym
    else
      raise "Location was not provided and no default location was found in #{CONFIG_FILE}."
    end
  end
end
