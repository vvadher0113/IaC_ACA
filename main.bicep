// =====================================================
// Azure Container Apps Bicep Template
// =====================================================

targetScope = 'subscription'

// ===========================================================================================================================================
// Parameters
// ===========================================================================================================================================
@description('Required. Azure region for all resources.')
param location string

@description('Required. Subscription ID where resources will be deployed.')
param SubscriptionId string

@description('Optional. Tags to apply to all resources.')
param tags object = {}

//============================================================================================================================================
// Feature Flags
//============================================================================================================================================
@description('Optional. Flag to deploy a new VNet. If false, existing subnets must be provided.')
param deployVNet bool = true

@description('Optional. Flag to deploy a Log Analytics Workspace.')
param deployLogAnalyticsWorkspace bool = true

@description('Optional. Flag to deploy an Azure Key Vault.')
param deployKeyVault bool = true

@description('Optional. Flag to deploy a Key Vault private endpoint.')
param deployKeyVaultPrivateEndpoint bool = true

@description('Optional. Flag to deploy an Azure Container Registry.')
param deployAcr bool = true

@description('Optional. Flag to deploy an ACR private endpoint.')
param deployAcrPrivateEndpoint bool = true

@description('Optional. Flag to deploy the Container Apps Managed Environment.')
param deployAcaEnvironment bool = true

@description('Optional. Flag to deploy the Container App.')
param deployContainerApp bool = true

@description('Optional. Flag to deploy the AcrPull role assignment for the Container App managed identity. Deploy after Phase 3.')
param deployAcrRoleAssignment bool = false

// ===========================================================================================================================================
// Azure Resource Naming Parameters
//============================================================================================================================================
@description('Required. Name of the resource group.')
param resourceGroupName string

@description('Required. Name of the virtual network.')
param vnetName string

@description('Required if deployLogAnalyticsWorkspace is true. Name of the Log Analytics Workspace.')
param logAnalyticsWorkspaceName string

@description('Required. Name of the Azure Key Vault.')
param keyVaultName string

@description('Required. Name of the Azure Container Registry.')
param acrName string

@description('Required. Name of the Container Apps Managed Environment.')
param acaEnvironmentName string

@description('Required. Name of the Container App.')
param containerAppName string

// ===========================================================================================================================================
// VNet Parameters
//============================================================================================================================================
@description('Required if deployVNet is true. Address space for the virtual network (e.g., ["10.0.0.0/16"]).')
param vnetAddressSpace array

@description('Required if deployVNet is true. Name of the subnet for private endpoints (ACR, Key Vault).')
param azureResourcesSubnetName string

@description('Required if deployVNet is true. Address prefix for the private endpoints subnet.')
param azzureResourcesSubnet string

@description('Required if deployVNet is true. Name of the subnet for ACA infrastructure. Minimum /27; /23+ recommended for production.')
param acaInfraSubnetName string

@description('Required if deployVNet is true. Address prefix for the ACA infrastructure subnet.')
param acaInfraSubnet string

// ===========================================================================================================================================
// Private DNS Zone Parameters
// ===========================================================================================================================================
@description('Optional. Resource ID of the private DNS zone for ACR (privatelink.azurecr.io). Leave empty to skip DNS zone configuration.')
param acrPrivateDnsZoneResourceId string = ''

@description('Optional. Resource ID of the private DNS zone for Key Vault (privatelink.vaultcore.azure.net). Leave empty to skip DNS zone configuration.')
param keyVaultPrivateDnsZoneResourceId string = ''

// ===========================================================================================================================================
// Log Analytics Workspace Parameters
//============================================================================================================================================
@description('Optional. Location for the Log Analytics Workspace. Defaults to the main location.')
param loganalyticsWorkspaceLocation string = location

@description('Optional. SKU for the Log Analytics Workspace.')
@allowed([
  'Free'
  'LACluster'
  'PerGB2018'
  'PerNode'
  'Premium'
  'Standalone'
  'Standard'
])
param logAnalyticsSkuName string = 'PerGB2018'

@description('Optional. Retention period in days for the Log Analytics Workspace.')
param logAnalyticsRetentionInDays int = 30

// ===========================================================================================================================================
// Azure Key Vault Parameters
// ===========================================================================================================================================
@description('Required. SKU for the Key Vault.')
param keyVaultSku string

// ===========================================================================================================================================
// Azure Container Registry Parameters
// ===========================================================================================================================================
@description('Required. SKU for the Azure Container Registry. Use Premium for private endpoint support.')
param acrSku string

@description('Optional. Zone redundancy for the ACR. Defaults to Disabled.')
param acrZoneRedundancy string = 'Disabled'

@description('Optional. Enable admin user on the ACR. Defaults to false.')
param acrAdminUserEnabled bool = false

@description('Optional. Soft delete policy status for the ACR.')
param acrsoftDeletePolicyStatus string = 'Disabled'

// ===========================================================================================================================================
// Container Apps Environment Parameters
// ===========================================================================================================================================
@description('Optional. Enable zone redundancy for the Container Apps Environment.')
param acaZoneRedundant bool = false

@description('Optional. Internal-only load balancer (no public ingress endpoint). Requires infrastructureSubnetResourceId.')
param acaInternalOnly bool = true

// ===========================================================================================================================================
// Container App Parameters
// ===========================================================================================================================================
@description('Optional. Container image to deploy.')
param containerAppImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Optional. Target port for ingress traffic.')
param containerAppTargetPort int = 8080

@description('Optional. Minimum number of replicas. Use 0 to allow scale-to-zero.')
@minValue(0)
param containerAppMinReplicas int = 0

@description('Optional. Maximum number of replicas.')
@minValue(1)
param containerAppMaxReplicas int = 3

// ===========================================================================================================================================
// Resource Group
//============================================================================================================================================
module resourceGroupModule 'bicep-avm-modules/avm/res/resources/resource-group/main.bicep' = {
  name: 'resourceGroupDeployment'
  scope: subscription(SubscriptionId)
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

//===========================================================================
// Virtual Network and Subnets
//===========================================================================
module vnetModule 'bicep-avm-modules/avm/res/network/virtual-network/main.bicep' = if (deployVNet) {
  name: 'vnetDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: vnetName
    location: location
    tags: tags
    addressPrefixes: vnetAddressSpace
    subnets: [
      {
        name: azureResourcesSubnetName
        addressPrefix: azzureResourcesSubnet
      }
      {
        name: acaInfraSubnetName
        addressPrefix: acaInfraSubnet
        delegation: 'Microsoft.App/environments'  // required for VNet-injected Container Apps Environment
      }
    ]
  }
}

//===========================================================================
// Log Analytics Workspace
//===========================================================================
module logAnalyticsWorkspace 'bicep-avm-modules/avm/res/operational-insights/workspace/main.bicep' = if (deployLogAnalyticsWorkspace) {
  name: 'logAnalyticsWorkspaceDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: logAnalyticsWorkspaceName
    location: loganalyticsWorkspaceLocation
    tags: tags
    skuName: logAnalyticsSkuName
    dataRetention: logAnalyticsRetentionInDays
  }
}

// ==========================================================================
// Azure Container Registry (Premium SKU, public access disabled, private endpoint)
// ==========================================================================
module acr 'bicep-avm-modules/avm/res/container-registry/registry/main.bicep' = if (deployAcr) {
  name: 'acrDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: acrName
    location: location
    tags: tags
    acrSku: acrSku
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: acrZoneRedundancy
    acrAdminUserEnabled: acrAdminUserEnabled
    softDeletePolicyStatus: acrsoftDeletePolicyStatus

    privateEndpoints: deployAcrPrivateEndpoint ? [
      {
        name: '${acrName}-pe'
        customNetworkInterfaceName: '${acrName}-pe-nic'
        service: 'registry'
        subnetResourceId: vnetModule!.outputs.subnetResourceIds[0]
        privateDnsZoneGroup: !empty(acrPrivateDnsZoneResourceId) ? {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: acrPrivateDnsZoneResourceId
            }
          ]
        } : null
      }
    ] : []
  }
}

// ==================================================================
// Azure Key Vault (public access disabled, private endpoint)
// ===================================================================
module keyVault './bicep-avm-modules/avm/res/key-vault/vault/main.bicep' = if (deployKeyVault) {
  name: 'KeyVaultDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: keyVaultName
    location: location
    sku: keyVaultSku
    tags: tags
    enableRbacAuthorization: true
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: []
      virtualNetworkRules: []
    }
    enableVaultForDeployment: false
    enableVaultForDiskEncryption: false
    enableVaultForTemplateDeployment: false
    privateEndpoints: deployKeyVaultPrivateEndpoint ? [
      {
        name: '${keyVaultName}-pe'
        customNetworkInterfaceName: '${keyVaultName}-pe-nic'
        subnetResourceId: vnetModule!.outputs.subnetResourceIds[0]
        service: 'vault'
        privateDnsZoneGroup: !empty(keyVaultPrivateDnsZoneResourceId) ? {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: keyVaultPrivateDnsZoneResourceId
            }
          ]
        } : null
      }
    ] : []
  }
}

// ===========================================================================
// Container Apps Managed Environment
//
// Network isolation is achieved via three controls:
//   internal: true             — internal-only LB, no public runtime endpoint
//   publicNetworkAccess: 'Disabled' — disables public management plane access
//   infrastructureSubnetResourceId  — VNet-injects the environment
//
// Note: The AVM app/managed-environment module does not expose a
// privateEndpoints parameter. VNet injection + internal mode is the
// equivalent pattern for Container Apps Environment isolation.
// ===========================================================================
module acaEnvironment 'bicep-avm-modules/avm/res/app/managed-environment/main.bicep' = if (deployAcaEnvironment) {
  name: 'acaEnvironmentDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  dependsOn: [
    resourceGroupModule
  ]
  params: {
    name: acaEnvironmentName
    location: location
    tags: tags
    infrastructureSubnetResourceId: vnetModule!.outputs.subnetResourceIds[1]
    internal: acaInternalOnly
    publicNetworkAccess: 'Disabled'
    managedIdentities: {
      systemAssigned: true
    }
    zoneRedundant: acaZoneRedundant
    appLogsConfiguration: deployLogAnalyticsWorkspace ? {
      destination: 'log-analytics'
      logAnalyticsWorkspaceResourceId: logAnalyticsWorkspace!.outputs.resourceId
    } : null
  }
}
// ===========================================================================
// Private Endpoint for Container Apps Environment
//============================================================================
module acaPrivateEndpoint 'modules/private-endpoint.bicep' = if (deployAcaEnvironment) {
  name: 'acaPrivateEndpointDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  params: {
    name: '${acaEnvironmentName}-pe'
    customNetworkInterfaceName: '${acaEnvironmentName}-pe-nic'
    location: location
    tags: tags
    subnetResourceId: vnetModule!.outputs.subnetResourceIds[0] // Use a non-delegated subnet for the PE
    privateLinkServiceId: acaEnvironment!.outputs.resourceId
    groupId: 'managedEnvironments' // Required group ID for ACA Environments
  }
}


// ===========================================================================
// Container App — pulls images from private ACR via system-assigned managed identity
// ===========================================================================
module containerApp 'bicep-avm-modules/avm/res/app/container-app/main.bicep' = if (deployAcaEnvironment && deployContainerApp) {
  name: 'containerAppDeployment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  params: {
    name: containerAppName
    location: location
    tags: tags
    environmentResourceId: acaEnvironment!.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    // Pull from private ACR using system-assigned managed identity (no admin credentials)
    registries: [
      {
        server: acr!.outputs.loginServer
        identity: 'system'
      }
    ]
    containers: [
      {
        name: containerAppName
        image: containerAppImage
        resources: {
          cpu: json('0.25')
          memory: '0.5Gi'
        }
      }
    ]
    // Internal environment — ingress is VNet-internal only, not exposed externally
    ingressExternal: false
    ingressTargetPort: containerAppTargetPort
    ingressAllowInsecure: false  // reject HTTP, enforce HTTPS (required for HIPAA/HiTrust)
    scaleSettings: {
      minReplicas: containerAppMinReplicas
      maxReplicas: containerAppMaxReplicas
    }
  }
}

// ===========================================================================
// Grant Container App system-assigned managed identity AcrPull on ACR
// Phase 4: run after Phase 3. The Container App's managed identity principal
// ID is automatically resolved from the deployed Container App.
// ===========================================================================
module acrPullRoleAssignment 'modules/acr-pull-role-assignment.bicep' = if (deployAcrRoleAssignment && deployContainerApp) {
  name: 'acrPullRoleAssignment'
  scope: resourceGroup(SubscriptionId, resourceGroupName)
  params: {
    acrName: acrName
    principalId: containerApp!.outputs.systemAssignedMIPrincipalId!
  }
}

// ========= //
// Outputs   //
// ========= //

@description('The name of the Azure Container Registry.')
output acrName string = (deployAcr && acr!.outputs.name != null) ? acr!.outputs.name : ''

@description('The login server of the Azure Container Registry.')
output acrLoginServer string = (deployAcr && acr!.outputs.loginServer != null) ? acr!.outputs.loginServer : ''

@description('The resource ID of the Azure Container Registry.')
output acrResourceId string = (deployAcr && acr!.outputs.resourceId != null) ? acr!.outputs.resourceId : ''

@description('The name of the Key Vault.')
output keyVaultName string = (deployKeyVault && keyVault!.outputs.name != null) ? keyVault!.outputs.name : ''

@description('The resource ID of the Key Vault.')
output keyVaultResourceId string = (deployKeyVault && keyVault!.outputs.resourceId != null) ? keyVault!.outputs.resourceId : ''

@description('The URI of the Key Vault.')
output keyVaultUri string = (deployKeyVault && keyVault!.outputs.uri != null) ? keyVault!.outputs.uri : ''

@description('The name of the Container Apps Managed Environment.')
output acaEnvironmentName string = deployAcaEnvironment ? acaEnvironment!.outputs.name : ''

@description('The default domain of the Container Apps Managed Environment.')
output acaEnvironmentDefaultDomain string = deployAcaEnvironment ? acaEnvironment!.outputs.defaultDomain : ''

@description('The static IP of the Container Apps Managed Environment.')
output acaEnvironmentStaticIp string = deployAcaEnvironment ? acaEnvironment!.outputs.staticIp : ''

@description('The name of the Container App.')
output containerAppName string = (deployAcaEnvironment && deployContainerApp) ? containerApp!.outputs.name : ''

@description('The FQDN of the Container App (internal to the VNet).')
output containerAppFqdn string = (deployAcaEnvironment && deployContainerApp) ? containerApp!.outputs.fqdn : ''
