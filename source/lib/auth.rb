require 'yaml'

CREDS_FILE="#{CONFIG_DIR}/auth"

class Auth

  def self.get_mfa_code
    print "Enter MFA: "
    STDOUT.flush
    STDIN.gets(7).chomp
  end

  def self.get_creds(username, defaults)
    region = defaults.fetch(:region)
    master = defaults.fetch(:master)
    master_account_number = master.fetch(:account_number)
    master_role_prefix = master.fetch(:role_prefix)
    master_role_name = master.fetch(:role_name)

    target = defaults.fetch(:target)
    target_account_number = target.fetch(:account_number)
    target_role_prefix = target.fetch(:role_prefix)
    target_role_name = target.fetch(:role_name)

    serial_number = "arn:aws:iam::#{master_account_number}:mfa/#{username}"
    puts "Logging into #{target.fetch(:label).upcase} using MFA: #{serial_number} (#{region})"
    role_arn = "arn:aws:iam::#{master_account_number}:role#{master_role_prefix}#{master_role_name}"
    session_name = username[0..31]

    sts_client = Aws::STS::Client.new(region: region)
    sts_role = sts_client.assume_role(role_arn: role_arn, role_session_name: session_name, serial_number: serial_number, token_code: get_mfa_code)
    creds = sts_role[:credentials]
    creds_obj = Aws::Credentials.new(creds.access_key_id, creds.secret_access_key, creds.session_token)

    role_arn = "arn:aws:iam::#{target_account_number}:role#{target_role_prefix}#{target_role_name}"
    session_name = username[0..31]
    sts_client = Aws::STS::Client.new(region: region, credentials: creds_obj)
    sts_role = sts_client.assume_role(role_arn: role_arn, role_session_name: session_name)
    creds = sts_role[:credentials]
    Aws::Credentials.new(creds.access_key_id, creds.secret_access_key, creds.session_token)
  end

  # TODO use keychain to save creds
  def self.login(options, defaults, plane)
    auth_file = "#{CREDS_FILE}.#{plane}"
    begin
      creds = YAML.load(File.read(auth_file))
      cf = Aws::CloudFormation::Client.new(region: defaults[:region], credentials: creds)
      cf.list_stacks # testing that creds are still good
    rescue => e
      begin
        profile_name = options[:profile]
        Aws.config[:credentials] = Aws::SharedCredentials.new(profile_name: profile_name)
        creds = get_creds(options.fetch(:username), defaults)
      rescue KeyError => e
        raise "Error parsing #{CONFIG_FILE}, (#{e.message}), please ensure it is properly formatted"
      end
      # now save to yaml
      File.open(auth_file, 'w') do |f|
        f.write YAML.dump(creds)
      end

      cf = Aws::CloudFormation::Client.new(region: defaults[:region], credentials: creds)
    end
    return cf, creds
  end
end
