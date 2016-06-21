

class RestackerConfig
  def self.load_config(plane)
    begin
      Dir.mkdir(CONFIG_DIR) unless Dir.exist?(CONFIG_DIR)
      if File.exist?(CONFIG_FILE)
        config = YAML.load_file(CONFIG_FILE)
      else
        config = YAML.load_file(SAMPLE_FILE)
        File.open(CONFIG_FILE, 'w') { |f| f.write config.to_yaml }
      end
    rescue Psych::SyntaxError
      raise "Improperly formatted YAML file: #{CONFIG_FILE}, please ensure it is properly formatted"
    rescue => e
      puts e.message
    end

    if config[plane].nil?
      puts "Plane not found (#{plane}), please see #{CONFIG_FILE}"
      exit
    end
    config[plane]
  end

end
