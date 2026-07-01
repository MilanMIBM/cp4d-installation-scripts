Setting up the model gateway with code
Last Updated
: 2026-05-07
The model gateway provides an API that is compatible with OpenAI and forwards inference requests to different foundation model providers.

Required permissions
To set up the model gateway in watsonx, you must have one of the following permissions:
Administrator platform
Manage configurations
Required credentials
You must generate credentials to authenticate with watsonx.ai APIs. For details, see Generating a bearer token.
Before you begin
Make sure the model gateway component is installed in your cluster by an instance administrator. For details, see Installing watsonx.ai in the IBM Software Hub documentation.

Provide credentials for each supported model provider that you plan to use and store each provider's API key in an environment variable.

For example, set the following environment variable to store credentials for the OpenAI model provider:

export OPENAI_APIKEY="<OpenAI API key>"

Procedure
Define and create a secret in the IBM Software Hub vault for a model provider that you want to configure. If you use an external vault, specify the arguments for the model provider when you create the secret. For more information, see Managing secrets and vaults.

The following table shows the configuration requirements for each supported model provider. For more details, see the respective provider's inference documentation.

Table 1. Configurations and endpoints for supported model providers
Provider name
Required arguments
Optional arguments
OpenAI • apiKey • base_url
IBM watsonx.ai • apiKey
• project_id or space_id • base_url
• auth_url
• api_version
Azure OpenAI • apiKey
• resource_name • subscription_id
• resource_group_name
•account_name
• api_version
Anthropic • apiKey -
AWS Bedrock • access_key_id
• secret_access_key
• region -
Cerebras • apiKey -
NVIDIA NIM • apiKey -
Google Gemini • apiKey -
Set the environment variable Vault_URN. You can copy the Vault_URN from the Administration > Configurations and settings > Vaults and secrets page by clicking the Copy icon Copy icon next to your secret name. For example, see the following command:

export Vault_URN="<user-id>:<secret-name>"

Run the following REST API request to configure a model provider:

  curl -sS https://<cpd_base_url>/ml/gateway/<provider-endpoint> \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg resource "${Vault_URN}" \
      --arg name "<custom-name-for-provider>" \
      '{name: $name, data_reference: {resource: $resource}}')"

If the internal vault is enabled, you can also configure credentials directly by running the following command:

  curl --request POST \
    --url https://<cpd_base_url>/ml/gateway<provider-endpoint>  \
    -H 'Authorization: Bearer ${TOKEN}' \
    -H 'Content-Type: application/json' \
    --data '{
    "data": {
      "apikey": "<model-provider-api-key>"
    },
    "name": "<custom-name-for-model-provider>"
  }'

After a model provider is added, you can add models from that provider by using the provider's UUID and the model's ID in the request. The model ID must be an existing unique identifier that is recognized by the provider. Since some models are available from multiple providers, you can use model aliases, which are custom names that reference models instead of using their model IDs. For example, see the following command:

curl -X POST "https://<cpd_base_url>/ml/gateway/v1/providers/${PROVIDER_UUID}/models" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{ "alias": "<custom-name-for-model>", "id": "<model_id>"}'
