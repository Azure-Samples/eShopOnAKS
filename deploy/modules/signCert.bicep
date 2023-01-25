param location string = 'eastus'
param VaultName string = 'akvw2pvax'
param CertName string = 'contoso'
param SubjectName string = 'CN=contoso.com'

resource managedIdentityCert 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: '${resourceGroup().name}-identity-cert'
  location: location
}

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: VaultName
}

resource aksVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: 'add'
  parent: vault
  properties: {
    accessPolicies: [
      {
        objectId: managedIdentityCert.properties.principalId
        permissions: {
          certificates: [
            'get'
            'create'
            'import'
          ]
        }
        tenantId: managedIdentityCert.properties.tenantId
      }
    ]
  }
}

resource newCert 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'newCert-${CertName}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityCert.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '7.5.0'
    arguments: ' -VaultName ${VaultName} -CertName ${CertName} -SubjectName ${SubjectName}'
    scriptContent: loadTextContent('NewCert.ps1')
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
  }
}

output CertName string = newCert.properties.outputs.CertName
