// =====================================================
// Private Endpoint Module
// =====================================================

targetScope = 'resourceGroup'

@description('Required. Location for the private endpoint.')
param location string

@description('Required. Name of the private endpoint.')
param name string

@description('Required. Custom NIC name for the private endpoint.')
param customNetworkInterfaceName string

@description('Required. Resource ID of the subnet for the private endpoint.')
param subnetResourceId string

@description('Required. Resource ID of the private link service (e.g. ACA Environment).')
param privateLinkServiceId string

@description('Required. Group ID for the private link connection (e.g. managedEnvironments).')
param groupId string

@description('Optional. Tags to apply to the private endpoint.')
param tags object = {}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    customNetworkInterfaceName: customNetworkInterfaceName
    subnet: {
      id: subnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-connection'
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: [
            groupId
          ]
        }
      }
    ]
  }
}

@description('The resource ID of the private endpoint.')
output resourceId string = privateEndpoint.id

@description('The name of the private endpoint.')
output name string = privateEndpoint.name
