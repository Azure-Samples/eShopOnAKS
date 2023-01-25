targetScope = 'subscription'

param resourceGroup string = 'cnny-week3'
param location string = deployment().location

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroup
  location: location
}

module aks './modules/aks.bicep' = {
  name: '${resourceGroup}-aks'
  scope: rg
  params: {
    location: location
    // clusterName:
    // nodeCount:
    // vmSize: 
    // kubernetesVersion:
  }
}

output acr_login_server_url string = aks.outputs.acr_login_server_url
output acr_name string = aks.outputs.acr_name
output aks_name string = aks.outputs.aks_name
output resource_group_name string = rg.name
