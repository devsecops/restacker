##Overview

There are 4 important files needed to make restacker work.

###Restacker.yml

First, you need to configure your `~/.restacker/restacker.yml` file.

This file is what allows your command line to connect and access the correct account.

Validation:
Keep tweaking this file until you can run `restacker list` and get a list of all the stacks.

###Template.json

Once this is complete, you need to get your hands on a template JSON file.

###Parameters.yml

After you have this you need to fill out your parameters.yml file. If your template has explanations for each field be sure to read them. 

This is the most diffcult step, while some of the parameters are not as critical as others, one mistyped letter and you will have no idea what the issue is because of the lack of error messages. 

Validation:
Once you can run `restacker deploy` and your stack returns Creation_Complete.

###Userdata.sh

After this, you may need to setup a userdata.sh file. 

This file is filled with commands that will be run after the instance is created. 

For example, if you needed curl installed, you could enter the command 'sudo yum install curl'. This will cause curl to be installed after the instance is booted.

####Diagram

The relationships between these four files are represented in this diagram.
![alt tag](Restacker.png)

##Execution
`restacker deploy -t <../Directory/To/Template> -n <Stack Name(Can be Anything)> -P <../Directory/To/parameters.yml> -l <AccountLabelInRestackerYml>`
