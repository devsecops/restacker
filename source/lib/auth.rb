require 'yaml'
require_relative 'restacker_config'

CREDS_FILE="#{CONFIG_DIR}/auth"

class Auth

  # TODO use keychain to save creds
  def self.login(options, config, location)
    auth_file     = "#{CREDS_FILE}.#{location}"
    region        = config.fetch(:region)
    profile_name  = RestackerConfig.find_profile(options)
    username      = RestackerConfig.find_user(options)

    # if no ctrl plane specified, authenticate directly
    return target_plane_auth(region, profile_name) if config[:ctrl].nil?

    if File.exists?(auth_file)
      session = YAML.load_file(auth_file)
      if session && valid_session?(region, session)
        create_auth_file(auth_file, session)
        return cloudformation_client(region, session)
      else # if session expired
        session = get_auth_session(profile_name, username, config)
        create_auth_file(auth_file, session)
        return cloudformation_client(region, session)
      end
    else # if file does not exist
      session = get_auth_session(profile_name, username, config)
      create_auth_file(auth_file, session)
      return cloudformation_client(region, session)
    end

  end

  private

  def self.get_mfa_code
    print Rainbow("Enter MFA: ").yellow
    STDOUT.flush
    STDIN.gets(7).chomp
  end

  def self.get_creds(username, config)
    region = config.fetch(:region)
    target = RestackerConfig.target_config(config) # target account will always exist in restacker.yml

    if config[:ctrl].nil?
      target_plane_auth(target)
    else
      ctrl = RestackerConfig.ctrl_config(config)
      control_plane_auth(ctrl, target, username, region)
    end
  end

  def self.control_plane_auth(ctrl, target, username, region)
    serial_number = "arn:aws:iam::#{ctrl[:account_number]}:mfa/#{username}"
    puts "Logging into #{Rainbow(target[:label].upcase).yellow} using MFA: #{serial_number} (#{region})"
    role_arn = "arn:aws:iam::#{ctrl[:account_number]}:role#{ctrl[:role_prefix]}#{ctrl[:role_name]}"
    session_name = username[0..31]

    sts_client = Aws::STS::Client.new(region: region)
    sts_role = sts_client.assume_role(role_arn: role_arn,
                                      role_session_name: session_name,
                                      serial_number: serial_number,
                                      token_code: get_mfa_code)
    creds = sts_role[:credentials]
    creds_obj = Aws::Credentials.new( creds.access_key_id,
                                      creds.secret_access_key,
                                      creds.session_token )

    role_arn = "arn:aws:iam::#{target[:account_number]}:role#{target[:role_prefix]}#{target[:role_name]}"
    session_name = username[0..31]
    sts_client = Aws::STS::Client.new(region: region, credentials: creds_obj)
    sts_role = sts_client.assume_role(role_arn: role_arn,
                                      role_session_name: session_name)
    creds = sts_role[:credentials]
    Aws::Credentials.new( creds.access_key_id,
                          creds.secret_access_key,
                          creds.session_token)
  end

  def self.target_plane_auth(region, profile_name)
    Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: profile_name)
    return Aws::CloudFormation::Client.new(region: region), Aws.config[:credentials].credentials
  end

  def self.valid_session?(region, creds)
    begin
      Aws::CloudFormation::Client.new(region: region, credentials: creds).list_stacks
      return true
    rescue Aws::CloudFormation::Errors::ExpiredToken => expired
      puts expired.message
      return false
    end
  end

  def self.get_auth_session(profile_name, username, config)
    Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: profile_name)

    get_creds(username, config)
  end

  def self.cloudformation_client(region, session)
    cf = Aws::CloudFormation::Client.new(region: region, credentials: session)
    return cf, session
  end

  def self.create_auth_file(file_name, session)
    File.open(file_name, 'w') do |f|
      f.write YAML.dump(session)
    end
  end
end
