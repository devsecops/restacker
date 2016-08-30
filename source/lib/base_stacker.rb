require 'aws-sdk'
require 'json'
require 'yaml'
require 'rainbow'

VERSION = '0.1.0'
CONFIG_DIR="#{ENV['HOME']}/.restacker"
CONFIG_FILE="#{CONFIG_DIR}/restacker.yml"
SAMPLE_FILE = "#{__dir__}/../restacker-sample.yml"

# needed here (after config_dir and defaults_file)
require_relative 'auth'

CREATE_COMPLETE = 'CREATE_COMPLETE'
CREATE_IN_PROGRESS = 'CREATE_IN_PROGRESS'
DELETE_IN_PROGRESS = 'DELETE_IN_PROGRESS'
DELETE_COMPLETE = 'DELETE_COMPLETE'

class BaseStacker
  def initialize(options)
    location = RestackerConfig.get_plane(options)
    config = RestackerConfig.load_config(location)

    # use default region if not passed in from cli
    config[:region] = options[:region] if options[:region]
    options[:region] = config[:region] unless options[:region]

    @cf, @creds = Auth.login(options, config, location)
    @options = options
  end
end
