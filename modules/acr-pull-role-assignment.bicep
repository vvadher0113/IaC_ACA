@description('Required. Name of the Azure Container Registry to assign the AcrPull role on.')
param acrName string

@description('Required. Principal ID (object ID) to assign the AcrPull role to.')
param principalId string

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, principalId, 'acrpull')
  scope: acr
  properties: {
    // AcrPull built-in role definition ID
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
