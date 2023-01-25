targetScope = 'subscription'

param resourceGroup string = 'cnny-week3'
param location string = deployment().location
param userObjectId string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroup
  location: location
}

module dns './modules/dns.bicep' = {
  name: '${resourceGroup}-dns'
  scope: rg
}
module aks './modules/aks.bicep' = {
  name: '${resourceGroup}-aks'
  scope: rg
  params: {
    location: location
    userObjectId: userObjectId
    dnsZoneResourceId: dns.outputs.dns_zone_id
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
output akv_name string = aks.outputs.akv_name
output service_account string = aks.outputs.service_account
output managed_identity_client_id string = aks.outputs.managed_identity_client_id
output dns_zone_name string = dns.outputs.dns_zone_name
