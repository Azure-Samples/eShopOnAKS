$githubOrganizationName = 'smurawski'
$githubRepositoryName  = 'eShopOnWeb'
$branchName = 'week3/day1'
$applicationName = 'cnny-week3-day1'

# Create an Azure AD application
aksDeploymentApplicationDetails=$(az ad app create --display-name $applicationName)
aksDeploymentApplicationObjectId=$(echo $aksDeploymentApplicationDetails | jq -r '.id')
aksDeploymentApplicationAppId=$(echo $aksDeploymentApplicationDetails | jq -r '.appId')

# Create a federated identity credential for the application
az ad app federated-credential create \
   --id $aksDeploymentApplicationObjectId \
   --parameters "{\"name\":\"${applicationName}\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:${githubOrganizationName}/${githubRepositoryName}:ref:refs/heads/${branchName}\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

# Create a service principal for the application
az ad sp create --id $aksDeploymentApplicationObjectId

# Assign the application permissions to the subscription to deploy the Bicep template
subscriptionId=(az account show --query id -o tsv)
az role assignment create \
   --assignee $aksDeploymentApplicationAppId \
   --role Owner \
   --scope "/subscriptions/${subscriptionId}"

# Create secrets in GitHub
echo "AZURE_CLIENT_ID: $aksDeploymentApplicationAppId"
echo "AZURE_TENANT_ID: $(az account show --query tenantId --output tsv)"
echo "AZURE_SUBSCRIPTION_ID: ${subscriptionId}"
