require 'aws-sdk'
require 'json'
require 'yaml'
require 'rainbow'

VERSION = '1.0.0'
CONFIG_DIR="#{ENV['HOME']}/.restacker"
CONFIG_FILE="#{CONFIG_DIR}/restacker.yml"
SAMPLE_FILE = "#{__dir__}/../restacker-example.yml"

# needed here (after config_dir and defaults_file)
require_relative 'auth'

STATUS = {
  CC: 'CREATE_COMPLETE',
  CIP: 'CREATE_IN_PROGRESS',
  CF: 'CREATE_FAILED',

  DC: 'DELETE_COMPLETE',
  DIP: 'DELETE_IN_PROGRESS',
  DF: 'DELETE_FAILED',

  UC: 'UPDATE_COMPLETE',
  UIP: 'UPDATE_IN_PROGRESS',
  UF: 'UPDATE_FAILED'
}

class BaseStacker
  def initialize(options)
    location = RestackerConfig.find_plane(options)
    config = RestackerConfig.load_config(location)
    # use default region if not passed in from cli
    config[:region] = options[:region] if options[:region]
    options[:region] = config[:region] unless options[:region]

    @cf, @creds = Auth.login(options, config, location)
    @options = options
  end
end
