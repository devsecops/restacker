# PARAMETERS.YML
Configurations to be passed to the CloudFormation template.

<!-- Explain each Parameter here -->
InstanceProfileName: Go to IAM -> roles and select one.

NotificationTopic: Go to SNS -> topics and select one.

**NOTE:** Any Environment variable that you'd like to persist past boot, place them here, **not** in `userdata.sh`
