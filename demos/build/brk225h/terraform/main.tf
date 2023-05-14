terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 2.39.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.56.0"
    }

    github = {
      source  = "integrations/github"
      version = "=5.25.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "2.4.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.20.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.9.0"
    }
  }
}

provider "azurerm" {
  features {
    app_configuration {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = true
    }

    cognitive_account {
      purge_soft_delete_on_destroy = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "github" {
  token = var.gh_token
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.build.kube_config.0.host
  username               = azurerm_kubernetes_cluster.build.kube_config.0.username
  password               = azurerm_kubernetes_cluster.build.kube_config.0.password
  client_certificate     = base64decode(azurerm_kubernetes_cluster.build.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.build.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.build.kube_config.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.build.kube_config.0.host
    username               = azurerm_kubernetes_cluster.build.kube_config.0.username
    password               = azurerm_kubernetes_cluster.build.kube_config.0.password
    client_certificate     = base64decode(azurerm_kubernetes_cluster.build.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.build.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.build.kube_config.0.cluster_ca_certificate)
  }
}

locals {
  name                                      = "brk225h${random_integer.build.result}"
  sql_admin_username                        = "eshopadmin"
  sql_admin_password                        = random_password.build.result
  sql_db_catalog                            = "eShopOnWeb.CatalogDb"
  sql_db_identity                           = "eShopOnWeb.Identity"
  repo_organization                         = var.gh_organization
  repo_name                                 = "eShopOnAKS"
  repo_branch                               = "build/brk225h"
  chat_completion_model_alias               = "chatgpt-azure"
  chat_completion_model_deploymentname      = "gpt-35-turbo"
  embedding_generation_model_alias          = "ada-azure"
  embedding_generation_model_deploymentname = "text-embedding-ada-002"
  text_completion_model_alias               = "davinci-azure"
  text_completion_model_deploymentname      = "text-davinci-003"
}

data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

resource "random_integer" "build" {
  min = 1000
  max = 9999
}

resource "random_password" "build" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "azuread_application" "build" {
  display_name = "app${local.name}"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "build" {
  application_id               = azuread_application.build.application_id
  app_role_assignment_required = true
  owners                       = [data.azurerm_client_config.current.object_id]
}

resource "azurerm_role_assignment" "build" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Owner"
  principal_id         = azuread_service_principal.build.object_id
}

resource "azuread_application_federated_identity_credential" "build" {
  application_object_id = azuread_application.build.object_id
  display_name          = "app${local.name}"
  audiences             = ["api://AzureADTokenExchange"]
  issuer                = "https://token.actions.githubusercontent.com"
  subject               = "repo:${local.repo_organization}/${local.repo_name}:ref:refs/heads/${local.repo_branch}"
}

resource "azurerm_resource_group" "build" {
  name     = "rg-${local.name}"
  location = var.location
}

resource "azurerm_cognitive_account" "build" {
  name                = "aoai${local.name}"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  kind                = "OpenAI"
  sku_name            = "S0"
}

resource "azurerm_cognitive_deployment" "aoai_davinci" {
  name                 = local.text_completion_model_deploymentname
  cognitive_account_id = azurerm_cognitive_account.build.id

  model {
    format  = "OpenAI"
    name    = local.text_completion_model_deploymentname
    version = "1"
  }

  scale {
    type = "Standard"
  }
}

resource "azurerm_cognitive_deployment" "aoai_ada" {
  name                 = local.embedding_generation_model_deploymentname
  cognitive_account_id = azurerm_cognitive_account.build.id

  model {
    format  = "OpenAI"
    name    = local.embedding_generation_model_deploymentname
    version = "1"
  }

  scale {
    type = "Standard"
  }

  depends_on = [
    azurerm_cognitive_deployment.aoai_davinci
  ]
}

resource "azurerm_cognitive_deployment" "aoai_gpt35" {
  name                 = local.chat_completion_model_deploymentname
  cognitive_account_id = azurerm_cognitive_account.build.id

  model {
    format  = "OpenAI"
    name    = local.chat_completion_model_deploymentname
    version = "0301"
  }

  scale {
    type = "Standard"
  }

  depends_on = [
    azurerm_cognitive_deployment.aoai_ada
  ]
}

resource "azurerm_container_registry" "build" {
  name                = "acr${local.name}"
  resource_group_name = azurerm_resource_group.build.name
  location            = azurerm_resource_group.build.location
  sku                 = "Premium"
  admin_enabled       = false
}

resource "azurerm_dashboard_grafana" "build" {
  name                              = "amg${local.name}"
  resource_group_name               = azurerm_resource_group.build.name
  location                          = azurerm_resource_group.build.location
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = true

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.build.id
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "amg_me" {
  scope                = azurerm_dashboard_grafana.build.id
  role_definition_name = "Grafana Admin"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_monitor_workspace" "build" {
  name                = "amon${local.name}"
  resource_group_name = azurerm_resource_group.build.name
  location            = azurerm_resource_group.build.location
}

resource "azurerm_role_assignment" "amon_me" {
  scope                = azurerm_monitor_workspace.build.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "amon_amg" {
  scope                = azurerm_monitor_workspace.build.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = azurerm_dashboard_grafana.build.identity[0].principal_id
}

resource "azurerm_log_analytics_workspace" "build" {
  name                = "alog${local.name}"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_kubernetes_cluster" "build" {
  name                 = "aks${local.name}"
  location             = azurerm_resource_group.build.location
  resource_group_name  = azurerm_resource_group.build.name
  dns_prefix           = "aks${local.name}"
  azure_policy_enabled = true

  default_node_pool {
    name                = "default"
    enable_auto_scaling = true
    max_count           = 10
    min_count           = 3
    vm_size             = "Standard_D4s_v5"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.build.id
  }

  identity {
    type = "SystemAssigned"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "1m"
  }

  service_mesh_profile {
    mode = "Istio"
  }

  workload_autoscaler_profile {
    keda_enabled = true
  }

  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.build.id
  }

  lifecycle {
    ignore_changes = [
      monitor_metrics
    ]
  }
}

resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.build.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.build.id
  skip_service_principal_aad_check = true
}

resource "null_resource" "aks_istio_ingress" {
  provisioner "local-exec" {
    command = "az aks mesh enable-ingress-gateway --resource-group ${azurerm_resource_group.build.name} --name ${azurerm_kubernetes_cluster.build.name} --ingress-gateway-type external"
  }
}

# resource "null_resource" "aks_monitor_metrics" {
#   provisioner "local-exec" {
#     command = "az aks update --name ${azurerm_kubernetes_cluster.build.name} --resource-group ${azurerm_resource_group.build.name} --azure-monitor-workspace-resource-id ${azurerm_monitor_workspace.build.id} --grafana-resource-id ${azurerm_dashboard_grafana.build.id}"
#   }

#   depends_on = [
#     azurerm_resource_group.build,
#     azurerm_kubernetes_cluster.build,
#     azurerm_monitor_workspace.build,
#     azurerm_dashboard_grafana.build,
#     null_resource.aks_istio_ingress
#   ]
# }

resource "null_resource" "amg_istio_folder" {
  provisioner "local-exec" {
    command = "az grafana folder create --name ${azurerm_dashboard_grafana.build.name} --resource-group ${azurerm_resource_group.build.name} --title 'Istio'"
  }

  depends_on = [
    azurerm_role_assignment.amg_me
  ]
}

resource "null_resource" "amg_istio_dashboard" {
  provisioner "local-exec" {
    command = "az grafana dashboard import --name ${azurerm_dashboard_grafana.build.name} --resource-group ${azurerm_resource_group.build.name} --folder 'Istio' --definition 7630"
  }

  depends_on = [
    azurerm_role_assignment.amg_me,
    null_resource.amg_istio_folder
  ]
}

resource "azurerm_app_configuration" "build" {
  name                = "aac${local.name}"
  location            = azurerm_resource_group.build.location
  resource_group_name = azurerm_resource_group.build.name
  sku                 = "standard"
}

resource "azurerm_role_assignment" "appconf_me" {
  scope                = azurerm_app_configuration.build.id
  role_definition_name = "App Configuration Data Owner"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_app_configuration_feature" "build" {
  configuration_store_id = azurerm_app_configuration.build.id
  name                   = "Chat"
  label                  = ""
  enabled                = false

  depends_on = [
    azurerm_role_assignment.appconf_me
  ]

  lifecycle {
    ignore_changes = [
      enabled
    ]
  }
}

resource "azurerm_app_configuration_key" "build_chatcompletion_model_alias" {
  configuration_store_id = azurerm_app_configuration.build.id
  key                    = "AzureOpenAISettings:ChatCompletionModel:Alias"
  value                  = local.chat_completion_model_alias

  depends_on = [
    azurerm_role_assignment.appconf_me
  ]
}


resource "azurerm_app_configuration_key" "build_chatcompletion_model_name" {
  configuration_store_id = azurerm_app_configuration.build.id
  key                    = "AzureOpenAISettings:ChatCompletionModel:DeploymentName"
  value                  = local.chat_completion_model_deploymentname

  depends_on = [
    azurerm_role_assignment.appconf_me
  ]
}

resource "azurerm_app_configuration_key" "build_embeddinggeneration_model_alias" {
  configuration_store_id = azurerm_app_configuration.build.id
  key                    = "AzureOpenAISettings:EmbeddingGenerationModel:Alias"
  value                  = local.embedding_generation_model_alias

  depends_on = [
    azurerm_role_assignment.appconf_me
  ]
}


resource "azurerm_app_configuration_key" "build_embeddinggeneration_model_name" {
  configuration_store_id = azurerm_app_configuration.build.id
  key                    = "AzureOpenAISettings:EmbeddingGenerationModel:DeploymentName"
  value                  = local.embedding_generation_model_deploymentname

  depends_on = [
    azurerm_role_assignment.appconf_me
  ]
}

resource "azurerm_app_configuration_key" "build_textcompletion_model_alias" {
  configuration_store_id = azurerm_app_configuration.build.id
  key                    = "AzureOpenAISettings:TextCompletionModel:Alias"
  value                  = local.text_completion_model_alias

  depends_on = [
    azurerm_role_assignment.appconf_me
  ]
}


resource "azurerm_app_configuration_key" "build_textcompletion_model_name" {
  configuration_store_id = azurerm_app_configuration.build.id
  key                    = "AzureOpenAISettings:TextCompletionModel:DeploymentName"
  value                  = local.text_completion_model_deploymentname

  depends_on = [
    azurerm_role_assignment.appconf_me
  ]
}

resource "azurerm_mssql_server" "build" {
  name                          = "sql${local.name}"
  resource_group_name           = azurerm_resource_group.build.name
  location                      = azurerm_resource_group.build.location
  version                       = "12.0"
  administrator_login           = local.sql_admin_username
  administrator_login_password  = local.sql_admin_password
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true
}

resource "azurerm_mssql_firewall_rule" "build" {
  name             = "AllowAllWindowsAzureIps"
  server_id        = azurerm_mssql_server.build.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_elasticpool" "build" {
  name                = "sqlep${local.name}"
  resource_group_name = azurerm_resource_group.build.name
  location            = azurerm_resource_group.build.location
  server_name         = azurerm_mssql_server.build.name
  max_size_gb         = 50
  license_type        = "LicenseIncluded"

  sku {
    name     = "GP_Gen5"
    tier     = "GeneralPurpose"
    family   = "Gen5"
    capacity = 2
  }

  per_database_settings {
    min_capacity = 0
    max_capacity = 2
  }
}

resource "azurerm_mssql_database" "sqldb_catalog" {
  name            = local.sql_db_catalog
  server_id       = azurerm_mssql_server.build.id
  collation       = "SQL_Latin1_General_CP1_CI_AS"
  elastic_pool_id = azurerm_mssql_elasticpool.build.id
  license_type    = "LicenseIncluded"
}

resource "azurerm_mssql_database" "sqldb_identity" {
  name            = local.sql_db_identity
  server_id       = azurerm_mssql_server.build.id
  collation       = "SQL_Latin1_General_CP1_CI_AS"
  elastic_pool_id = azurerm_mssql_elasticpool.build.id
  license_type    = "LicenseIncluded"
}

resource "azurerm_key_vault" "build" {
  name                        = "akv${local.name}"
  location                    = azurerm_resource_group.build.location
  resource_group_name         = azurerm_resource_group.build.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    certificate_permissions = [
      "Backup",
      "Create",
      "Delete",
      "DeleteIssuers",
      "Get",
      "GetIssuers",
      "Import",
      "List",
      "ListIssuers",
      "ManageContacts",
      "ManageIssuers",
      "Purge",
      "Recover",
      "Restore",
      "SetIssuers",
      "Update"
    ]

    key_permissions = [
      "Backup",
      "Create",
      "Decrypt",
      "Delete",
      "Encrypt",
      "Get",
      "Import",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Sign",
      "UnwrapKey",
      "Update",
      "Verify",
      "WrapKey",
      "Release",
      "Rotate",
      "GetRotationPolicy",
      "SetRotationPolicy"
    ]

    secret_permissions = [
      "Backup",
      "Delete",
      "Get",
      "List",
      "Purge",
      "Recover",
      "Restore",
      "Set"
    ]

    storage_permissions = [
      "Backup",
      "Delete",
      "DeleteSAS",
      "Get",
      "GetSAS",
      "List",
      "ListSAS",
      "Purge",
      "Recover",
      "RegenerateKey",
      "Restore",
      "Set",
      "SetSAS",
      "Update"
    ]
  }
}

resource "azurerm_key_vault_secret" "secret_aoai_key" {
  name         = "openai-api-key"
  value        = azurerm_cognitive_account.build.primary_access_key
  key_vault_id = azurerm_key_vault.build.id
}

resource "azurerm_key_vault_secret" "secret_aoai_url" {
  name         = "openai-api-url"
  value        = azurerm_cognitive_account.build.endpoint
  key_vault_id = azurerm_key_vault.build.id
}

resource "azurerm_key_vault_secret" "secret_sql_password" {
  name         = "sqlserver-password"
  value        = local.sql_admin_password
  key_vault_id = azurerm_key_vault.build.id
}

resource "azurerm_key_vault_secret" "secret_catalog_connection" {
  name         = "catalog-db-connection"
  value        = "Server=tcp:${azurerm_mssql_server.build.name}.database.windows.net,1433;Initial Catalog=${local.sql_db_catalog};Persist Security Info=False;User ID=${local.sql_admin_username};Password=${local.sql_admin_password};MultipleActiveResultSets=False;Encrypt=true;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.build.id
}

resource "azurerm_key_vault_secret" "secret_identity_connection" {
  name         = "identity-db-connection"
  value        = "Server=tcp:${azurerm_mssql_server.build.name}.database.windows.net,1433;Initial Catalog=${local.sql_db_identity};Persist Security Info=False;User ID=${local.sql_admin_username};Password=${local.sql_admin_password};MultipleActiveResultSets=False;Encrypt=true;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.build.id
}

resource "azurerm_key_vault_secret" "secret_aac_connection" {
  name         = "app-config-connection"
  value        = azurerm_app_configuration.build.primary_write_key[0].connection_string
  key_vault_id = azurerm_key_vault.build.id
}

resource "azurerm_load_test" "build" {
  location            = azurerm_resource_group.build.location
  name                = "alt${local.name}"
  resource_group_name = azurerm_resource_group.build.name
}

resource "github_actions_secret" "gh_actions_app_id" {
  repository      = local.repo_name
  secret_name     = "AZURE_CLIENT_ID"
  plaintext_value = azuread_application.build.application_id
}

resource "github_actions_secret" "gh_actions_tenant_id" {
  repository      = local.repo_name
  secret_name     = "AZURE_TENANT_ID"
  plaintext_value = data.azurerm_client_config.current.tenant_id
}

resource "github_actions_secret" "gh_actions_subscription_id" {
  repository      = local.repo_name
  secret_name     = "AZURE_SUBSCRIPTION_ID"
  plaintext_value = data.azurerm_subscription.current.subscription_id
}

resource "github_actions_secret" "gh_actions_user_object_id" {
  repository      = local.repo_name
  secret_name     = "AZURE_USER_OBJECT_ID"
  plaintext_value = azuread_service_principal.build.object_id
}

resource "github_actions_secret" "gh_actions_acr_name" {
  repository      = local.repo_name
  secret_name     = "ACR_NAME"
  plaintext_value = azurerm_container_registry.build.name
}

resource "github_actions_secret" "gh_actions_aks_name" {
  repository      = local.repo_name
  secret_name     = "AKS_NAME"
  plaintext_value = azurerm_kubernetes_cluster.build.name
}

resource "github_actions_secret" "gh_actions_rg_name" {
  repository      = local.repo_name
  secret_name     = "RG_NAME"
  plaintext_value = azurerm_resource_group.build.name
}

resource "kubernetes_namespace" "build" {
  metadata {
    labels = {
      "istio.io/rev" = "asm-1-17"
    }

    name = "eshop"
  }
}

resource "kubernetes_config_map" "prometheus" {
  metadata {
    name      = "ama-metrics-prometheus-config"
    namespace = "kube-system"
  }

  data = {
    "prometheus-config" = file("prometheus-config")
  }
}

// TODO: AUTOMATE THE MANAGED IDENTITY ON VMSS

# resource "helm_release" "appconfig_provider" {
#   name             = "azureappconfiguration.kubernetesprovider"
#   namespace        = "azappconfig-system"
#   create_namespace = true
#   chart            = "oci://mcr.microsoft.com/azure-app-configuration/helmchart/kubernetes-provider"
#   version          = "1.0.0-preview"
#   cleanup_on_fail  = true
# }

# resource "kubernetes_manifest" "appconfig_provider" {
#   manifest = {
#     apiVersion = "azconfig.io/v1beta1"
#     kind       = "AzureAppConfigurationProvider"
#     metadata = {
#       name      = "appconfigurationprovider-sample"
#       namespace = "eshop"
#     }
#     spec = {
#       endpoint = azurerm_app_configuration.build.endpoint
#       target = {
#         configMapName = "configmap-created-by-appconfig-provider"
#       }
#     }
#   }

#   depends_on = [helm_release.appconfig_provider]
# }


resource "local_file" "kubeconfig" {
  filename = "aks-kubeconfig"
  content  = azurerm_kubernetes_cluster.build.kube_config_raw
}

data "external" "ingress" {
  program = ["kubectl", "--kubeconfig", "${local_file.kubeconfig.filename}", "get", "service", "aks-istio-ingressgateway-external", "-n", "aks-istio-ingress", "-o", "jsonpath={.status.loadBalancer.ingress[0]}"]

  depends_on = [
    null_resource.aks_istio_ingress
  ]
}

resource "kubernetes_config_map" "build" {
  metadata {
    name      = "eshop-configs"
    namespace = "eshop"
  }

  data = {
    AOAI_ENDPOINT                        = azurerm_cognitive_account.build.endpoint
    AOAI_CHATCOMPLETION_MODEL_ALIAS      = local.chat_completion_model_alias
    AOAI_CHATCOMPLETION_MODEL_DEPLOYMENT = local.chat_completion_model_deploymentname
    AOAI_EMBEDDING_MODEL_ALIAS           = local.embedding_generation_model_alias
    AOAI_EMBEDDING_MODEL_DEPLOYMENT      = local.embedding_generation_model_deploymentname
    AOAI_TEXTCOMPLETION_MODEL_ALIAS      = local.text_completion_model_alias
    AOAI_TEXTCOMPLETION_MODEL_DEPLOYMENT = local.text_completion_model_deploymentname
    CHAT_URL                             = "http://${data.external.ingress.result["ip"]}/chat"
    API_URL                              = "http://${data.external.ingress.result["ip"]}/api/"
    WEB_URL                              = "http://${data.external.ingress.result["ip"]}"
  }
}

resource "kubernetes_secret" "build" {
  metadata {
    name      = "eshop-secrets"
    namespace = "eshop"
  }

  data = {
    SQL_CONNECTION_CATALOG  = "Server=tcp:${azurerm_mssql_server.build.name}.database.windows.net,1433;Initial Catalog=${local.sql_db_catalog};Persist Security Info=False;User ID=${local.sql_admin_username};Password=${local.sql_admin_password};MultipleActiveResultSets=False;Encrypt=true;TrustServerCertificate=False;Connection Timeout=30;"
    SQL_CONNECTION_IDENTITY = "Server=tcp:${azurerm_mssql_server.build.name}.database.windows.net,1433;Initial Catalog=${local.sql_db_identity};Persist Security Info=False;User ID=${local.sql_admin_username};Password=${local.sql_admin_password};MultipleActiveResultSets=False;Encrypt=true;TrustServerCertificate=False;Connection Timeout=30;"
    APP_CONFIG_CONNECTION   = azurerm_app_configuration.build.primary_write_key[0].connection_string
    AOAI_KEY                = azurerm_cognitive_account.build.primary_access_key
  }
}