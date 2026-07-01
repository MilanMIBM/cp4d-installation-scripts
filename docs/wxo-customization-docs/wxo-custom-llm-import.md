Large Language Models (LLMs)
Managing virtual models
You can integrate third-party LLM models from a variety of supported providers as virtual models.
​
Supported providers
Provider Provider ID
OpenAI openai
watsonx.ai watsonx
Groq groq
Anthropic anthropic
Google Gen AI google
Gemini Enterprise Agent Platform vertex-ai
Azure AI azure-ai
Azure OpenAI azure-openai
AWS Bedrock bedrock
Mistral mistral-ai
OpenRouter openrouter
x.ai x-ai
Ollama ollama
Note:
When importing a model from OpenRouter, always set the max_token parameter explicitly. If you skip this step, the system defaults to 65536 tokens. This high token count can cause the request to fail if you don't have enough credits.
GPT-OSS-120b is a non-IBM product governed by a third-party license that may impose use restrictions and other obligations. By using this model you agree to the terms. Read the terms.
​
Understanding Virtual Models
You can configure watsonx Orchestrate to register an external model/provider, also known as a virtual model. However, there are important considerations:
​
Compatibility and Support
Not every model and provider combination is supported or tested. While the supported providers list shows providers that have been tested in the past, this does not guarantee that every model on every listed provider will work. Consider the following:
New models and API changes: Models are released frequently, and some introduce API specification changes that may cause runtime errors
Intermediate infrastructure: If there are components in the request path between watsonx Orchestrate and the provider (such as gateways, proxies, or adapters), these may introduce incompatibilities or special authentication requirements that watsonx Orchestrate does not support
Model suitability: Not all models are well-suited for agentic workflows. Even when a model registers successfully and runs without errors, the results may not be accurate enough for business-critical agents
​
Optimized Support
watsonx Orchestrate provides optimized support for:
gpt-oss-120b via Groq or AWS Bedrock providers
gpt-oss-120b via watsonx.ai in GovCloud environments (available April mid-release)
These model/provider combinations have undergone extensive testing and optimization for agent workflows.
​
Testing Requirements
When registering virtual models with other providers, allocate sufficient time to validate that the combination works correctly. Testing may identify incompatibilities that prevent the agent from functioning as expected.
​
Using Custom Provider Endpoints
If you self-host an LLM or have a model proxy/gateway as a pass-through to another provider, you may be able to leverage OpenAI chat completion compatibility. This section covers authentication options for custom endpoints.
​
OpenAI-Compatible with API Key Authentication
The default base URL for the openai provider is <https://api.openai.com/v1>. For self-hosted OpenAI-compatible endpoints, ensure your full URL ends with /chat/completions, but exclude this path when providing the custom_host during registration.
Authentication format:
Authorization: Bearer ${apiKey}
Example:
1
Define the model specification

custom-openai-model.yaml
spec_version: v1
kind: model
name: openai/your-model-id
model_type: chat
provider_config:
  api_key: "your-apikey"
  custom_host: "<https://your-url>"
Note: Do not include /chat/completions in the custom_host value.
2
Register the model

orchestrate models import --file custom-openai-model.yaml
​
OpenAI-Compatible with OAuth 2.0 Authentication
For self-hosted OpenAI-compatible endpoints that use OAuth 2.0 client credentials authentication, use the openai-oauth2-client-creds provider type. This is appropriate when your OAuth token endpoint is separate from your LLM inferencing endpoint.
Prerequisites: Your LLM inferencing URL must:
End with /chat/completions (per OpenAI spec)
Accept OAuth tokens in the request header: Authorization: Bearer your-access-token
1
Create OAuth connection

First, create a Team application/connection in watsonx Orchestrate. See OAuth 2.0 Client Credentials for details.
Example OAuth token endpoint:
response = requests.post(
    token_url,
    auth=(client_id, client_secret),
    headers={"Content-Type": "application/x-www-form-urlencoded"},
    data={"grant_type": "client_credentials"}
)
2
Register the model

orchestrate models add \
  --name "openai-oauth2-client-creds/your-model-id" \
  --provider-config '{"custom_host": "<https://your-llm-inferencing-url"}>' \
  --app-id your-app-id-from-step-1
Note: Exclude /chat/completions from the custom_host value.
Custom endpoints and intermediate infrastructure (proxies, gateways) may not be fully supported. Ensure thorough testing before production use.
​
CLI Reference
Importing from a file
Using the CLI only
You can add a virtual model to watsonx Orchestrate using the orchestrate models import command.
1
Define the model specification file

granite-3-3-8b-model.yaml
spec_version: v1
kind: model
name: virtual-model/watsonx/ibm/granite-3.3-8b-instruct
display_name: IBM watsonx.ai (Granite)
description: |
IBM watsonx.ai model using Space-scoped configuration.
tags:

- ibm
- watsonx
model_type: chat
provider_config:
    watsonx_space_id: my-space-id # For any non-sensitive field not already provided by the connection
Show properties

2
Create an API key connection

BASH
orchestrate connections add -a watsonx_credentials
orchestrate connections configure -a watsonx_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a watsonx_credentials --env draft -e "api_key=my_watsonx_api_key"
3
Add the model

BASH
orchestrate models import --file watsonx-model.yaml --app-id watsonx_credentials
Arguments:
--file (-f): File path of the spec file containing the model configuration.
--app-id (-a): The app ID of a key_value connection containing provider configuration details. These will be merged with the values provided in the provider_config section of the spec.
​
Examples using the supported providers
The following sections contain examples and the supported schemas for each model provider.
OpenAI

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider
​
custom_host
string
Send requests to a custom hostname other than the default for the provider
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
​
transform_to_form_data
boolean
Transforms the request to form_data.
Example usage:
1
Define the model specification file

Then, you can define a specification file to provide the details about the model and the provider configuration specifications:
gpt-5-2025-08-07.yaml
spec_version: v1
kind: model
name: openai/gpt-5-2025-08-07
display_name: GPT 5
description: |-
    GPT-5 is our flagship model for coding, reasoning, and agentic tasks across domains. Learn more in our GPT-5 usage guide.
tags:

- openai
- gpt
model_type: chat
provider_config:
    custom_host: <https://my-openai-compatible-server>
2
Create an API key connection

To safely use the OpenAI API key, you must first create a connection:
BASH
orchestrate connections add -a openai_credentials
orchestrate connections configure -a openai_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a openai_credentials --env draft -e "api_key=my_openai_key"
3
Add the model

You can now add the model using the specification file and the connection that you created:
BASH
orchestrate models import --file gpt-5-2025-08-07 --app-id openai_credentials
watsonx.ai

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider.
​
custom_host
stringrequired
The service instance url of the watsonx.ai instance
​
watsonx_space_id
stringconditionally required
At least one of space/project/deployment is required
​
watsonx_project_id
stringconditionally required
At least one of space/project/deployment is required
​
watsonx_deployment_id
stringconditionally required
At least one of space/project/deployment is required
​
watsonx_cpd_url
stringconditionally required
When connecting to a watsonx.ai instance hosted in CPD, this is the url of the CPD cluster hosting watsonx.ai.
Required connecting to on-prem (CPD) hosted wx.ai instances
​
watsonx_cpd_username
stringconditionally required
When connecting to a watsonx.ai instance hosted in CPD, this is username of a user with access to the CPD cluster.
Required connecting to on-prem (CPD) hosted wx.ai instances
​
watsonx_cpd_password
stringconditionally required
When connecting to a watsonx.ai instance hosted in CPD, this is password of a user with access to the CPD cluster.
Required connecting to on-prem (CPD) hosted wx.ai instances
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

watsonx-model.yaml
spec_version: v1
kind: model
name: watsonx/ibm/granite-3.3-8b-instruct
display_name: IBM watsonx.ai (Granite)
description: |
    IBM watsonx.ai model using Space-scoped configuration.
tags:

- ibm
- watsonx
model_type: chat
provider_config:
    watsonx_space_id: my-space-id
2
Create an API key connection

BASH
orchestrate connections add -a watsonx_credentials
orchestrate connections configure -a watsonx_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a watsonx_credentials --env draft -e "api_key=my_watsonx_api_key"
Note:
When you add a watsonx.ai virtual model, include the provider-config details. Without them, chat access to the model may fail. Provide custom host details using the -provider-config flag in the orchestrate models add command. For more information, see Using the CLI only.
3
Add the model

BASH
orchestrate models import --file watsonx-model.yaml --app-id watsonx_credentials
Notes:
Provide one of: watsonx_space_id, watsonx_project_id, or watsonx_deployment_id.
Include watsonx_cpd_url, watsonx_cpd_username, watsonx_cpd_password only for on-prem (CPD) setups.
When deploying Deploy on Demand (DoD) models, you need to explicitly provide the model configuration during registration. Set these configuration values according to the model's requirements, since they don't automatically transfer during inference from the watsonx Orchestrate side.
Show example

Groq

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider
​
custom_host
stringrequired
Send requests to a custom hostname for the provider
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

Then, you can define a specification file to provide the details about the model and the provider configuration specifications:
gpt-oss-120b.yaml
spec_version: v1
kind: model
name: virtual-model/groq/openai/gpt-oss-120b
display_name: openai/gpt-oss-120b # Optional
description: Welcome to the gpt-oss series, OpenAI's open-weight models designed for powerful reasoning, agentic tasks, and versatile developer use cases.
tags:

- openai
- gpt-oss-120b
model_type: chat # Optional. Default is "chat". Options: ["chat"|"embedding"]
app_id: groq_credentials
provider_config:
    custom_host: <https://api.groq.com/openai/v1>
2
Create an API key connection

To safely use the API key, you must first create a connection:
BASH
orchestrate connections add -a groq_credentials
orchestrate connections configure -a groq_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a groq_credentials --env draft -e "api_key=my_openai_key"
3
Add the model

You can now add the model using the specification file and the connection that you created:
BASH
orchestrate models import --file gpt-oss-120b.yaml --app-id groq_credentials
Anthropic

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider.
​
anthropic_beta
string
​
anthropic_version
string
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

anthropic-claude.yaml
spec_version: v1
kind: model
name: anthropic/claude-3
display_name: Anthropic Claude 3
description: |
    Anthropic Claude model for safe and helpful AI interactions.
tags:

- anthropic
- claude
model_type: chat
provider_config: {}
2
Create an API key connection

BASH
orchestrate connections add -a anthropic_credentials
orchestrate connections configure -a anthropic_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a anthropic_credentials --env draft -e "api_key=my_anthropic_key"
3
Add the model

BASH
orchestrate models import --file anthropic-claude.yaml --app-id anthropic_credentials
Google Gen AI

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider.
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

google-genai.yaml
spec_version: v1
kind: model
name: google/gemini-2.5-pro
display_name: Google Generative AI (Gemini 2.5 Pro)
description: |
    Google Generative AI model via API key authentication.
tags:

- google
- genai
model_type: chat
provider_config: {}
2
Create an API key connection

BASH
orchestrate connections add -a google_credentials
orchestrate connections configure -a google_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a google_credentials --env draft -e "api_key=my_google_api_key"
3
Add the model

BASH
orchestrate models import --file google-genai.yaml --app-id google_credentials
Gemini Enterprise Agent Platform

Known Limitations:
API key authentication is not supported. Use service account JSON authentication instead.
For more details, see Known issues and limitations.
​
provider_config
object
The fields which can be set in the provider_config field of the model.
Hide properties

​
vertex_region
stringrequired
The GCP region for Gemini Enterprise Agent Platform.
​
vertex_service_account_json
object
The complete service account JSON object for authentication. This includes all necessary credentials for accessing Gemini Enterprise Agent Platform.
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds.
Example usage:
1
Define the model specification file

my-provider.yaml
spec_version: v1
kind: model
name: vertex-ai/gemini-3.1-pro-preview
display_name: Gemini Enterprise Agent Platform (Gemini 3.1 Pro)
description: Gemini Enterprise Agent Platform model via service account authentication
tags:

- google
- vertex-ai
model_type: chat
provider_config:
  vertex_region: <region>
  vertex_service_account_json:
    type: service_account
    project_id: <project-id>
    private_key_id: <private-key-id>
    private_key: <private-key>
    client_email: <client-email>
    client_id: <client-id>
    auth_uri: <auth-uri>
    token_uri: <token-uri>
    auth_provider_x509_cert_url: <auth-provider-cert-url>
    client_x509_cert_url: <client-cert-url>
    universe_domain: <universe-domain>
2
Add the model

BASH
orchestrate models import --file my-provider.yaml
Azure

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider
​
azure_resource_name
stringrequired
​
azure_deployment_id
stringrequired
​
azure_api_version
stringrequired
​
azure_model_name
stringrequired
​
custom_host
string
Send requests to a custom hostname other than the default for the provider
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

azure-gpt.yaml
spec_version: v1
kind: model
name: azure/gpt-4
display_name: Azure GPT-4
description: |
    Azure-hosted GPT model for enterprise-grade AI workloads.
tags:

- azure
- gpt
model_type: chat
provider_config:
    azure_resource_name: my-resource
    azure_deployment_id: my-deployment
    azure_api_version: 2024-05-01
2
Create an API key connection

BASH
orchestrate connections add -a azure_credentials
orchestrate connections configure -a azure_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a azure_credentials --env draft -e "api_key=my_azure_key"
3
Add the model

BASH
orchestrate models import --file azure-gpt.yaml --app-id azure_credentials
Azure OpenAI

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider
​
azure_model_name
string
​
azure_resource_name
stringrequired
​
azure_deployment_id
stringrequired
​
azure_api_version
stringrequired
​
ad_auth
boolean
​
azure_auth_mode
string
​
azure_managed_client_id
string
​
azure_entra_client_id
string
​
azure_entra_client_secret
string
​
azure_entra_tenant_id
string
​
azure_ad_token
string
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

azure-openai-gpt.yaml
spec_version: v1
kind: model
name: azure-openai/gpt-4
display_name: Azure OpenAI GPT-4
description: |
    Azure OpenAI GPT-4 model for enterprise workloads.
tags:

- azure
- openai
model_type: chat
provider_config:
    azure_resource_name: my-resource
    azure_deployment_id: my-deployment
    azure_api_version: 2024-05-01
    custom_host: <host_url>
2
Create an API key connection

BASH
orchestrate connections add -a azure_openai_credentials
orchestrate connections configure -a azure_openai_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a azure_openai_credentials --env draft -e "api_key=my_azure_openai_key"
3
Add the model

BASH
orchestrate models import --file azure-openai-gpt.yaml --app-id azure_openai_credentials
AWS Bedrock

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider.
Either the api_key must be provided, or both the aws_secret_access_key and aws_access_key_id must be provided
​
aws_secret_access_key
stringrequired
The aws_secret_access_key.
Either the api_key must be provided, or both the aws_secret_access_key and aws_access_key_id must be provided
​
aws_access_key_id
stringrequired
The aws_access_key_id.
Either the api_key must be provided, or both the aws_secret_access_key and aws_access_key_id must be provided
​
aws_session_token
string
​
aws_region
string
​
aws_auth_type
string
​
aws_role_arn
string
​
aws_external_id
string
​
aws_s3_bucket
string
​
aws_s3_object_key
string
​
aws_bedrock_model
string
​
aws_server_side_encryption
string
​
aws_server_side_encryption_kms_key_id
string
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

aws-bedrock-model.yaml
spec_version: v1
kind: model
name: bedrock/us.anthropic.claude-3-5-sonnet-20241022-v2:0
display_name: AWS Bedrock Claude
description: |
    AWS Bedrock integration for foundation models like Claude.
tags:

- aws
- bedrock
model_type: chat
provider_config:
    aws_region: us-east-1
2
Create an API key connection

BASH
orchestrate connections add -a aws_bedrock_credentials
orchestrate connections configure -a aws_bedrock_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a aws_bedrock_credentials --env draft -e "api_key=my_aws_key"
3
Add the model

BASH
orchestrate models import --file aws-bedrock-model.yaml --app-id aws_bedrock_credentials
Note:
You must provide either the api_key, aws_secret_access_key, or aws_access_key_id.
You must provide the model name in the name field.
When deploying Deploy on Demand (DoD) models, you need to explicitly provide the model configuration during registration. Set these configuration values according to the model's requirements, since they don't automatically transfer during inference from the watsonx Orchestrate side.
Show example

Mistral

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider.
​
mistral_fim_completion
boolean
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Define the model specification file

mistral-large.yaml
spec_version: v1
kind: model
name: mistralai/mistral-7b-instruct-v0.3
display_name: Mistral 7B Instruct v0.3
description: |
    Mistral model for general-purpose reasoning and coding tasks.
tags:

- mistral
model_type: chat
provider_config:
    mistral_fim_completion: false
2
Create an API key connection

BASH
orchestrate connections add -a mistral_credentials
orchestrate connections configure -a mistral_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a mistral_credentials --env draft -e "api_key=my_mistral_api_key"
3
Add the model

BASH
orchestrate models import --file mistral-large.yaml --app-id mistral_credentials
OpenRouter

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider.
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Create an API key connection

BASH
orchestrate connections add -a openrouter_credentials
orchestrate connections configure -a openrouter_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a openrouter_credentials --env draft -e "api_key=my_openrouter_api_key"
2
Define the model specification file

openrouter-model.yaml
spec_version: v1
kind: model
name: openrouter/openai/gpt-5
display_name: OpenRouter GPT-5 Chat
description: |
    OpenRouter model for routing requests across multiple LLM providers.
tags:

- openrouter
- gpt
model_type: chat
provider_config: {}
3
Add the model

BASH
orchestrate models import --file openrouter-model.yaml --app-id openrouter_credentials
x.ai

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider.
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
Example usage:
1
Create an API key connection

BASH
orchestrate connections add -a xai_credentials
orchestrate connections configure -a xai_credentials --env draft -k key_value -t team
orchestrate connections set-credentials -a xai_credentials --env draft -e "api_key=xai_api_key"
2
Define the model specification file

xai-model.yaml
spec_version: v1
kind: model
name: virtual-model/x-ai/grok
display_name: Grok
description: |
    x.ai model
tags:

- x.ai
- gpt
model_type: chat
provider_config: {}
3
Add the model

BASH
orchestrate models import --file xai-model.yaml --app-id xai_credentials
Ollama

​
provider_config
object
The fields which can either be set by connection or by the provider_config field of the model. Values from a connection will be merged with the provider_config.
Hide properties

​
api_key
stringrequired
The API key for the provider
​
custom_host
stringrequired
Send requests to a custom hostname other than the default for the provider
​
url_to_fetch
stringconditionally required
The Ollama url to fetch the list of available ollama models
​
response_headers
list[string]
Add one or more additional response headers in the form ["header:value", "header2:value2"] to the request to the server.
​
response_timeout
number
The response timeout in seconds
​
transform_to_form_data
boolean
Transforms the request to form_data.
Example usage:
1
Start ollama

In some systems, ollama might run under the systemctl, so you need to stop it before you run the Ollama server:
systemctl stop ollama
Then you can start the Ollama server and download the model, if it has not started yet:
ollama pull llama3.2:latest
export OLLAMA_HOST=0.0.0.0:11434
ollama serve
2
Get your IP address

You can get your network IP address by running:

Windows

Linux

macOS
ipconfig # get the IPv4 address
3
Testing your connection

Before you import the model, it is a good idea to test your connection to guarantee the watsonx Orchestrate Developer Edition server can connect to the Ollama server.
Use the following curl command to test your connection, replacing 198.51.100.42 with the IP address that you obtained in the previous step:
curl --request POST \
--url <http://198.51.100.42:11434/v1/chat/completions> \
--header 'content-type: application/json' \
--data '{
"model": "llama3.2:latest",
"messages": [
{
"content": "Hi",
"role": "user"
}
]
}'
Enter the watsonx Orchestrate Developer Edition gateway container:
docker exec -it docker-wxo-agent-gateway-1 sh
Run the curl command again from within the container shell.
Tips: If you experience connection issues with Ollama:
Wait a few minutes after starting the server before running the command.
Restart the Ollama server.
Close any VPN clients.
Try reconnecting to both Wi-Fi and wired Ethernet simultaneously.
Avoid switching networks during the process.
Reset the watsonx Orchestrate Developer Edition server:
orchestrate server reset
4
Define the model specification file

For Ollama, you don't need to create a connection or use an actual API key. You can use a string such as ollama as an API key.
You must use your current local network IP address as your URL. Ollama will not work if you use localhost or 0.0.0.0 in the model specification file.
ollama-llama2.yaml
spec_version: v1
kind: model
name: ollama/llama3.2:latest
display_name: Ollama LLaMA 3.2
description: |
    Ollama-hosted LLaMA 3.2 model for local or edge deployments.
tags:

- ollama
- llama2
model_type: chat
provider_config:
    api_key: ollama
    custom_host: <http://198.51.100.42:11434>
Remember: Replace <http://198.51.100.42:11434> with the IP address that you have obtained in the previous step.
5
Add the model

BASH
orchestrate models import --file ollama-llama2.yaml
​
List all LLMs
Run the orchestrate models list command to see all available LLMs in your active environment.
BASH
orchestrate models list
Note:
By default, you see a table of available models. If you prefer raw output, add the --raw (-r) flag.
​
Removing custom LLMs
Run the orchestrate models remove command and use the --name (-n) flag to specify the LLM you want to remove.
BASH
orchestrate models remove -n <model-name-unique-identifier-to-delete>
​
Exporting custom LLM
Run the orchestrate models export command to export LLMs in your active environment.
BASH
orchestrate models export -n <model_name> -o <path>.zip
Hide command flags

Flag Type Required Description
--name (-n) string Yes The model name to export.
--output (-o) string Yes The file path where the exported data is saved.
​
Updating custom LLM
To update a custom LLM, first remove it, then add it again:
BASH
orchestrate models remove -n <model-name-unique-identifier-to-delete>
orchestrate models add --name watsonx/meta-llama/llama-3-2-90b-vision-instruct --app-id watsonx_ai_creds
​
Additional configuration options
​
Setting a default LLM in the UI
If you use an on-premises installation with models provisioned only as virtual models, you can choose which model appears as the default in the user interface. To do this, add the default tag under the tags section of a model with the type set to chat.
granite-default-model.yaml
spec_version: v1
kind: model
name: watsonx/ibm/granite-3.3-8b-instruct
display_name: IBM watsonx.ai (Granite)
description: |
    IBM watsonx.ai model using Space-scoped configuration.
tags:

- default # <-- this marks this as the Default model in the ui dropdown
model_type: chat
provider_config:
    watsonx_space_id: my-space-id
See all 11 lines
Note:
For on-premises installations using only externally hosted virtual-models, at least one model must be specified as the default model or it will not be possible to open the “Create Agent” page in the UI.
​
Setting a default embedding model
If you use an on-premises installation with models provisioned only as virtual models, you can also set a default model for knowledge bases. To do this, add the default tag under the tags section of a model with the type set to embedding.
virtual-model.yaml
spec_version: v1
kind: model
name: virtual-model/watsonx/ibm/slate-30m-english-rtrvr-v2
display_name: slate30m
tags:
  - default
model_type: embedding
provider_config:
  watsonx_space_id: xxx
  customHost: '<https://us-south.ml.cloud.ibm.com>'
  api_key: xxx
See all 11 lines
​
Registering a watsonx model by using your watsonx credentials
You can also register a watsonx model that uses your watsonx credentials supplied in your .env file when you start the watsonx Orchestrate Developer Edition.
For that, your .env file must contain either:
Your watsonx.ai credentials with the WATSONX_APIKEY and WATSONX_SPACE_ID environment variables.
Or, your watsonx Orchestrate credentials with the WO_INSTANCE and WO_API_KEY environment variables.
To learn how to configure you .env file with these credentials, see Installing the watsonx Orchestrate Developer Edition.
To register the watsonx model using this method, set the api_key credential value to “gateway”. You do not need to specify a space_id when you add the model. See the following example:
Note:
This requirement does not apply to on-premises deployments.
BASH
orchestrate connections configure -a wx_gw_creds --env draft -k key_value -t team
orchestrate connections set-credentials -a wx_gw_creds --env draft -e "api_key=gateway"
orchestrate models add --name "watsonx/meta-llama/llama-3-2-90b-vision-instruct"  --app-id wx_gw_creds

#### Configuring LLM parameters

You can configure additional LLM parameters such as temperature and seed for more control over model behavior. These parameters can be set in your agent configuration:

```yaml
llm_config:
  seed: 123
  temperature: 0.0
Parameters:
seed: Sets a random seed for reproducible outputs (useful for testing and debugging)
temperature: Controls randomness in responses (0.0 = deterministic, higher values = more creative)
These settings apply to the specific agent and override any default model configurations.
