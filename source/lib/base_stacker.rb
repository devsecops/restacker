require 'aws-sdk'
require 'yaml'
require 'json'

VERSION = '0.0.11'
CONFIG_DIR="#{ENV['HOME']}/.restacker"
CONFIG_FILE="#{CONFIG_DIR}/restacker.yml"
SAMPLE_FILE = "#{__dir__}/../restacker-sample.yml"

# needed here (after config_dir and defaults_file)
require_relative 'auth'

DEFAULT_PLANE = :ksp

CREATE_COMPLETE = 'CREATE_COMPLETE'
CREATE_IN_PROGRESS = 'CREATE_IN_PROGRESS'
DELETE_IN_PROGRESS = 'DELETE_IN_PROGRESS'
DELETE_COMPLETE = 'DELETE_COMPLETE'

class BaseStacker
  def initialize(options)
    @plane = options[:location] ? options[:location].to_sym : DEFAULT_PLANE
    config = RestackerConfig.load_config(@plane)
    # use default region if not passed in from cli
    config[:region] = options[:region] if options[:region]
    options[:region] = config[:region] unless options[:region]
    @cf, @creds = Auth.login(options, config, @plane)
    @options = options
  end
end
