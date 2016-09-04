# RESTACKER.YML
This is the configuration file for Restacker CLI.  
See the sample [here](../source/restacker-example.yml).

## STRUCTURE
In order for Restacker to work as expected, the following key:value pairs are required:
### GENERAL DEFAULTS
- `:default:`: This specifies the default location/plane for all Restacker operations. This is intended to save you from having to specify the required `-l <location>` everytime.
  - `:label:`: Set this to the name of your preferred default location.
  - `:profile:`: Set this to your preferred default AWS profile (see `~/.aws/credentials`)

### CONTROL PLANE DEFAULTS
- `:ctrl: &ctrl_default`: This is the default Control-Plane configuration. Do not change this line.
  - `:label:`: Set this to the name of your control account.
  - `:role-name:`: Set this to the name of the Control-Plane Role you wish to assume.
  - `:role-prefix:`: Set this to the prefix of the Control-Plane Role you wish to assume.
  - `:bucket:`: S3 Bucket configuration to read/consume files from. Do not change this line.
    - `:name:`: Set this to the S3 bucket name.
    - `:prefix:`: **optional** Set this to the bucket prefix/path where CloudFormation Templates & approved AMIs are stored.
    - `:ami_key:`: **optional** Set this to name of the object on S3 that contains list of approved AMIs.

### TARGET PLANE SETTINGS
- `:acctName:`: This represents the name of the account.
  - `:region:`: Set this to the default region you wish to operate in.
  - `:ctrl:`: This represents the control plane for this account. Do not change this line.
    - `<<: *ctrl_default`: if the control plane configuration for this account is the default account specified above (see `:ctrl: &ctrl_default` section), then just insert default configurations here.
  - `:target:`: This represents the target plane configuration. Do not change this line.
    - `:label:`: Set this to the name of the target account.
    - `:account_number:`: Set this to the target account number.
    - `:role_name:`: Set this to the target role name you wish to assume.
    - `:role_prefix:`: Set this to the prefix of the target role you wish to assume.

### NON-CONTROL-PLANE ACCOUNTS (AKA DIRECT ACCOUNTS)
Not all accounts fall under the Control-Plane architecture. Some accounts are accessible directly without having to assume roles from Control Accounts and Target Accounts, such as testing or learning accounts.
- `:learn:`: This represents the name of the direct target account
  - `:region:`: Set this to the region you wish to operate in.
  - `:profile:`: Set this to the profile name of this account (see `~/.aws/credentials`).
  - `:target:`: This represents the target account information. Do not change this line.
    - `:label:`: Set this to the name of your account.
    - `:account_number:`: Set this to the account number.
    - `:bucket:`: This represents the S3 bucket settings for the direct target account. Do not change this line.
      - `:name:`: Set this to the name of the S3 bucket
      - `:prefix:`: Set this to the bucket prefix where CloudFormation templates are stored.

## Example Restacker Configuration:
```
:default:
  :label: myapp1

:ctrl: &ctrl_default
  :label: ctrlAcct
  :account_number: '123456789012'
  :role_name: ctrl-ctrl-DeployAdmin
  :role_prefix: "/dso/ctrl/ctrl/"
  :bucket:
    :name: my-bucket
    :prefix: "s3/bucket/prefix/"
    :ami_key: ami_object_key

:ctrlAcct:
  :region: us-west-2
  :ctrl:
    <<: *ctrl_default
  :target:
    <<: *ctrl_default

:myapp1:
  :region: us-west-2
  :ctrl:
    <<: *ctrl_default
    :role_name: ctrl-myapp1-DeployAdmin
  :target:
    :label: myapp1
    :account_number: '098765432123'
    :role_name: myapp1-dso-DeployAdmin
    :role_prefix: "/dso/human/"

:myapp2:
  :region: us-west-2
  :ctrl:
    <<: *ctrl_default
    :role_name: ctrl-myapp2-DeployAdmin
  :target:
    :label: myapp2
    :account_number: '123098456765'
    :role_name: myapp2-dso-DeployAdmin
    :role_prefix: "/dso/human/"

:learn:
  :region: us-west-2
  :profile: learning-profile
  :target:
    :label: myLearningAccount
    :account_number: '123456789012'
    :bucket:
      :name: my-learning-bucket

```
