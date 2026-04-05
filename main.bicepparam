using './main.bicep'

param location = 'West US'
param SubscriptionId = ''

param tags = {
  environment: 'dev'
  project: 'aca-deployment'
  owner: 'Vijay Vadher'
}

// ===========================================================================================================================================
// Feature Flags
// ===========================================================================================================================================
  // Phase 1: Core Infrastructure
param deployVNet = false
param deployLogAnalyticsWorkspace = false
param deployKeyVault = false
param deployAcr = false

  // Phase 2: Private Endpoints
param deployKeyVaultPrivateEndpoint = false
param deployAcrPrivateEndpoint = false

  // Phase 3: Container Apps Environment + App
param deployAcaEnvironment = false
param deployContainerApp = false

  // Phase 4: ACR Role Assignment
  // Assigns AcrPull to the Container App's system-assigned managed identity.
param deployAcrRoleAssignment = false

// ===========================================================================================================================================
// Azure Resource Naming Parameters
// ===========================================================================================================================================
param resourceGroupName = 'vv-aca-rg'
param vnetName = 'vv-aca-vnet'
param logAnalyticsWorkspaceName = 'vv-aca-log'
param keyVaultName = 'vv-aca-kv'
param acrName = 'vvacacr01'
param acaEnvironmentName = 'vv-aca-env'
param containerAppName = 'vv-aca-app'

// ===========================================================================================================================================
// VNet Parameters
// ===========================================================================================================================================
param vnetAddressSpace = ['10.250.250.0/24']
param azureResourcesSubnetName = 'AzureResourcesSubnet'
param azzureResourcesSubnet = '10.250.250.0/26'    // Private endpoints (ACR, Key Vault)
param acaInfraSubnetName = 'AcaInfraSubnet'
param acaInfraSubnet = '10.250.250.64/26'           // ACA Environment infrastructure (min /27; /23+ for production)

// ===========================================================================================================================================
// Private DNS Zone Parameters
// ===========================================================================================================================================
param acrPrivateDnsZoneResourceId = '/subscriptions/ca16bf0f-3a7a-42e8-9e31-f7f558d91ad1/resourceGroups/vv-aca-rg/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io'
param keyVaultPrivateDnsZoneResourceId = '/subscriptions/ca16bf0f-3a7a-42e8-9e31-f7f558d91ad1/resourceGroups/vv-aca-rg/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net'

// ===========================================================================================================================================
// Log Analytics Workspace Parameters
// ===========================================================================================================================================
param loganalyticsWorkspaceLocation = 'West US'
param logAnalyticsSkuName = 'PerGB2018'
param logAnalyticsRetentionInDays = 30

// ===========================================================================================================================================
// Azure Key Vault Parameters
// ===========================================================================================================================================
param keyVaultSku = 'standard'

// ===========================================================================================================================================
// Azure Container Registry Parameters
// ===========================================================================================================================================
param acrSku = 'Premium'
param acrZoneRedundancy = 'Disabled'
param acrAdminUserEnabled = false
param acrsoftDeletePolicyStatus = 'disabled'

// ===========================================================================================================================================
// Container Apps Environment Parameters
// ===========================================================================================================================================
param acaZoneRedundant = false
param acaInternalOnly = true   // Internal-only LB — no public runtime endpoint

// ===========================================================================================================================================
// Container App Parameters
// ===========================================================================================================================================
param containerAppImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param containerAppTargetPort = 80
param containerAppMinReplicas = 0    // 0 = scale-to-zero enabled
param containerAppMaxReplicas = 3
