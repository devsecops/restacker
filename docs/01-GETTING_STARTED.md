# INTRODUCTION

The Control-Plane pattern/architecture is designed to mitigate and limit risk/exposure if an account were to be compromised.  
In DevSecOps, we call this **Blast Radius**.

## CONTROL PLANE
In a typical Control-Plane architecture, an account is designated as the Control Plane.  
It does not have any instances (e.g. EC2, RDS ...etc).  
The main purpose of this account is to maintain users and roles.

## TARGET PLANE
The target plane, or account, will host the instances, databases, and any other AWS services needed.  
The roles in this account trusts roles from the Control Plane/Account

## WORKFLOW
In a Control-Plane architecture, the workflow for performing operations on the Target Account will look like this:
 - Authenticate against the Control Account to obtain an AWS STS token.
 - Pass that STS token to the next Target Account to assume a specific role (e.g. Read-Only, Deploy-Admin, Incident-Response ...etc).

## GETTING STARTED
There are 4 important files needed to make `restacker` work:

### [Restacker Config File](02-RESTACKER_YML.md)
- This file specifies the control plane and target accounts for Restacker to connect and access the correct accounts.
- You may initialize the `restacker.yml` configuration file by typing `restacker configure -l <target account>` or by copying the [sample config file](../restacker-example.yml)

To confirm that your `restacker.yml` configuration is correct, `restacker list` should return a list of stacks for a particular account.

### [Parameters File](03-PARAMETERS_YML.md)
- The `parameters.yml` file contains all the custom properties/attributes of your service
- See [example](../Infrastructure/Parameters/webapp-parameter-example.yml)


### [CloudFormation Template](04-CLOUDFORMATION_JSON.md)
- The data from `parameters.yml` file will be injected into the CloudFormation template.
- See the [Web-App CloudFormation Template Example](../Infrastructure/CloudFormation/webapp-example.json)

### [Userdata Script](05-USERDATA_SH.md)
- The `userdata.sh` script will contain commands that will be run after the instance is created.
- This script is expected to live in an S3 bucket that is accessible by said instance.
- See [example](../Infrastructure/userdata/webapp-userdata-example.sh).

![alt tag](Restacker.png)

### Execution
- Once all elements are available and complete, you may deploy/re-stack new instances with:
`restacker deploy -t <./path/to/template.json> -n <Stack Name(Can be Anything)> -P <./path/to/parameters.yml> -l <Account Label in Restacker.yml (e.g. myapp1)>`

### Diagram
The relationships between these four files are represented in this diagram.
