targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string

var abbreviations = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// 리소스를 리소스 그룹으로 구성
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${abbreviations.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// 모니터링: Log Analytics 배포
module logAnalytics 'core/monitor/loganalytics.bicep' = {
  name: 'loganalytics'
  scope: rg
  params: {
    name: '${abbreviations.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
  }
}

// 모니터링: Application Insights 배포
module applicationInsights 'core/monitor/applicationinsights.bicep' = {
  name: 'applicationinsights'
  scope: rg
  params: {
    name: '${abbreviations.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
  }
}

// 스토리지: Storage Account 배포 (AI 서비스 종속성)
module storage 'core/storage/storage-account.bicep' = {
  name: 'storage'
  scope: rg
  params: {
    name: '${abbreviations.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    allowSharedKeyAccess: false
  }
}

// AI: Azure AI Hub, Project 및 모델(gpt-4o-mini) 배포
module ai 'core/ai/cognitiveservices.bicep' = {
  name: 'ai'
  scope: rg
  params: {
    aiServiceName: '${abbreviations.cognitiveServicesAccounts}${resourceToken}'
    aiProjectName: '${abbreviations.cognitiveServicesAccounts}proj-${resourceToken}'
    location: location
    tags: tags
    appInsightsId: applicationInsights.outputs.id
    appInsightConnectionString: applicationInsights.outputs.connectionString
    appInsightConnectionName: 'app-insights-connection' 
    aoaiConnectionName: 'aoai-connection'
    storageAccountId: storage.outputs.id
    storageAccountConnectionName: 'storage-connection'
    storageAccountBlobEndpoint: storage.outputs.primaryEndpoints.blob
    deployments: [
      {
        name: 'gpt-4o-mini'
        model: {
          format: 'OpenAI'
          name: 'gpt-4o-mini'
          version: '2024-07-18' // gpt-4o-mini 특정 버전 지정
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 10
        }
      }
    ]
  }
}

// 보안: 사용자에게 역할 할당 (Cognitive Services Contributor) - 에이전트 생성 권한 포함
module role 'core/security/role.bicep' = {
  name: 'role-assignment'
  scope: rg
  params: {
    principalId: principalId
    roleDefinitionId: 'a97b65f3-24c7-4388-baec-2e87135dc908' // Cognitive Services Contributor
    principalType: 'User'
  }
}

output AZURE_KEY_VAULT_ENDPOINT string = '' // Placeholder if needed
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_RESOURCE_GROUP string = rg.name
output AZURE_AI_PROJECT_CONNECTION_STRING string = ai.outputs.projectEndpoint
output AZURE_AI_PROJECT_NAME string = ai.outputs.projectName
output AZURE_AI_SERVICE_NAME string = ai.outputs.serviceName
