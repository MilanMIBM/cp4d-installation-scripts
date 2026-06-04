Configuring environments
Configure access to remote environments
The watsonx Orchestrate ADK introduces environments (env), which represent instances of watsonx Orchestrate you can access.
Environments can be:
Local: Running on your laptop using the Developer Edition of watsonx Orchestrate.
Remote: Hosted on IBM Cloud, AWS, or on-premises using Cloud Pak for Data.
When you activate an environment, all commands, except orchestrate server and orchestrate chat, target that environment. This includes importing, listing, and removing agents, tools, and connections.
​
Environment commands
​
Adding an environment
Use the orchestrate env add command to add a remote environment to your local CLI. To learn where to find your service instance url and api key see Getting credentials for your environments.
BASH
orchestrate env add -n <environment-name> -u <your-instance-url>  
Note:
You can set any name you prefer for the environment.
When you use a HIPAA‑regulated cluster, you must include the --iam-url parameter.
Example:
BASH
orchestrate env add -n <onprem-environment-name> --iam-url https://api.us-east-1-reg.watson-orchestrate.ibm.com -u <watsonxorchestrateinstance>
For on-premises environments, you can ignore invalid SSL certificates, if your environment uses a self-signed certificate:
BASH
orchestrate env add -n <onprem-environment-name> -u <your-instance-url> --insecure
Hide command flags

​
--name / -n
stringrequired
The name of the environment.
​
--url / -u
stringrequired
The service instance URL of the watsonx Orchestrate instance. This can be found on the service instance page.
​
--type / -t
string
Optional, usually inferred based on the URL provided, but this allows you to specify what type of authentication your server uses. The following options are the accepted values for the type of environment:
ibm_iam: For environments on IBM Cloud using IBM Identity and Access Management (IAM).
mcsp: For environments on AWS using Multi-Cloud SaaS Platform (MCSP) authentication. Tries MCSP v2 first, then falls back to v1 if needed.
mcsp_v1: For AWS environments using MCSP v1 authentication.
mcsp_v2: For AWS environments using MCSP v2 authentication.
cpd: For on-premises environments.
​
--activate / -a
string
Optional, allows you to activate the environment as soon as it’s added.
​
--insecure
boolean
Ignore SSL validation errors. Used for on-premises environments only.
​
--verify
string
Provide a path to an SSL certificate. Used for on-premises environments only.
​
Activating an environment
Use the orchestrate env activate command to authenticate against a given environment and target all commands other than orchestrate server and orchestrate chat to that environment.
Note: Authentication against a remote environment expires every two hours. After expiration, you need to run orchestrate env activate again. This behavior does not exist in the local environment.
To interactively activate an environment:
BASH
orchestrate env activate <environment-name>
Please enter WXO API key: 
To non-interactively log in for scripting, use the following:
BASH
orchestrate env activate <environment-name> --api-key <your-api-key>
For on-premises environments:
BASH
orchestrate env activate <onprem-environment-name> --username=<username> --password=<password>
You can also use an api-key in the on-premises environment:
BASH
orchestrate env activate <onprem-environment-name> --username=<username> --api-key=<api-key>
Hide command flags

​
--api-key / -a
stringrequired
The watsonx Orchestrate API Key. You can see how to get your API key in ./production_import. Prior to version 1.6.0 of the ADK, this flag was --apikey. For on-premises environments, use it alongside --username.
​
--username
string
Username of the user in the environment. It is only valid for on-premises environments. You must either use it alongside an --api-key or a --password, but not both.
​
--password
string
Password of the user in the on-premises environment. Can’t be used if you provide an --api-key.
​
Listing all environments
Use the orchestrate env list command to list all environments currently available to your CLI.
By default, you have one known as local. Your local environment refers to the watsonx Orchestrate Development Edition server. Others can be added by using the orchestrate env add command. The currently active environment will be indicated by an indicator saying (active) at the end of the line.
BASH
orchestrate env list
​
Removing an environment
Use the orchestrate env remove command to remove an environment from your environment list.
BASH
orchestrate env remove -n <environment-name>
​
Important configuration files
The watsonx Orchestrate CLI maintains two configuration files which are manipulated by the above env commands.
The first is ~/.config/orchestrate/config.yaml. This configuration file records each of your environments as well as which environment is currently active.
The second is ~/.cache/orchestrate/credentials.yaml. This file contains the JWT token from your last env activation used to authenticate with your environment.