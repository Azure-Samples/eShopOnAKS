resource dnsZone 'Microsoft.Network/dnsZones@2018-05-01' = {
  name: 'eshoponweb${substring('${uniqueString(subscription().id)}${uniqueString(resourceGroup().id)}', 0, 5)}.com'
  location: 'Global'
  properties: {
    zoneType: 'Public'
  }
}

output dns_zone_id string = dnsZone.id
output dns_zone_name string = dnsZone.name
