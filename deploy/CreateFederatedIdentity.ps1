$githubOrganizationName = 'smurawski'
$githubRepositoryName  = 'eShopOnWeb'
$branchName = 'week3/day1'
$applicationName = 'cnny-week3-day1'

# Create an Azure AD application
$aksDeploymentApplication = New-AzADApplication -DisplayName $applicationName

# Create a federated identity credential for the application
New-AzADAppFederatedCredential `
   -Name $applicationName `
   -ApplicationObjectId $aksDeploymentApplication.Id `
   -Issuer 'https://token.actions.githubusercontent.com' `
   -Audience 'api://AzureADTokenExchange' `
   -Subject "repo:$($githubOrganizationName)/$($githubRepositoryName):ref:refs/heads/$branchName"

# Create a service principal for the application
New-AzADServicePrincipal -AppId $($aksDeploymentApplication.AppId)

# Assign the application permissions to the subscription to deploy the Bicep template
$azureContext = Get-AzContext
New-AzRoleAssignment `
   -ApplicationId $($aksDeploymentApplication.AppId) `
   -RoleDefinitionName Owner `
   -Scope $azureContext.Subscription.Id

# Create secrets in GitHub
if (get-command gh -ea SilentlyContinue) {
   # If you have the gh CLI installed, directly create the secrets

   gh secret set AZURE_CLIENT_ID --body $aksDeploymentApplication.AppId
   gh secret set AZURE_TENANT_ID --body $azureContext.Tenant.Id
   gh secret set AZURE_SUBSCRIPTION_ID --body $azureContext.Subscription.Id
}
else {
   Write-Host "Create these secrets in your GitHub repository:"
   Write-Host "  AZURE_CLIENT_ID: $($aksDeploymentApplication.AppId)"
   Write-Host "  AZURE_TENANT_ID: $($azureContext.Tenant.Id)"
   Write-Host "  AZURE_SUBSCRIPTION_ID: $($azureContext.Subscription.Id)"
}
