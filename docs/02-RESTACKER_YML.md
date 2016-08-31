# RESTACKER.YML
This is the configuration file for Restacker CLI.  
See the sample [here](../source/restacker-sample.yml).

## STRUCTURE
In order for Restacker to work as expected, the following key:value pairs are required:
- `:default:`: specifies the default location/plane for all Restacker operations. This is intended to save you from having to specify the required `-l <location>` everytime.
  - `:label:`: the name of the default location.
- `:ctrl: &ctrl_default`: default configuration for the Control Account
  - `:label:`: name of the account
  - `:role-name:`
  - `:role-prefix:`
  - `:bucket:`: S3 Bucket configuration to read/consume files from.
    - `:name:`: Bucket name
    - `:prefix:`: **optional** bucket prefix/path
    - `:ami_key:`: **optional** name of object on S3 that contains list of approved AMIs
- `:Account_Name:`: name of target account
  - `:region:`: default region to deploy instances in (e.g. `us-west-2`)
  - `:ctrl:`: control account for this account
    - `<<: *ctrl_default`: if the control account is the default account specified in `&ctrl_default`, then just insert default configurations here
  - `:target:`: the target account configuration
    - `:label:`: name of target account
    - `:account_number:`: target account number
    - `:role_name:`: target role name
    - `:role_prefix:`: target role prefix

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
    :name: kaos-installers
    :prefix: cloudformation
    :ami_key: latest_amis

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

```
