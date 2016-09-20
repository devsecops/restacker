##Overview

There are 4 important files needed to make restacker work.

###Restacker.yml

First, you need to configure your `~/.restacker/restacker.yml` file.

This file is what allows your command line to connect and access the correct account.

Validation:
`restacker list` should return a list of stacks for a particular account, if it does not, you may need to tweak your restacker.yml. There is an example located in the Readme file `../Readme.md`.

###Template.json

You need to get your hands on a template JSON file. There is an example template.json provided here `../Infrastructure/CloudFormation/webapp-example.json`

###Parameters.yml

You will need to fill out your parameters.yml file. If your template has explanations or descriptions for each field be sure to read them. 

This is the most diffcult step, while some of the parameters are not as critical as others, one mistyped letter and you will have no idea what the issue is because of the lack of error messages. 

If you are having trouble there is an example located here `../Infrastructure/parameters/`

Validation:
`restacker deploy` should run and return `Creation_Complete`.

###Userdata.sh

You may need to setup a userdata.sh file. 

This file is filled with commands that will be run after the instance is created. 

For example, if you needed curl installed, you could enter the command 'sudo yum install curl'. This will cause curl to be installed after the instance is booted.

An example is found here `../Infrastructure/userdata/

####Diagram

The relationships between these four files are represented in this diagram.


![alt tag](Restacker.png)

##Execution
`restacker deploy -t <../Directory/To/Template> -n <Stack Name(Can be Anything)> -P <../Directory/To/parameters.yml> -l <Account Label in Restacker.yml ex. myapp1>`
