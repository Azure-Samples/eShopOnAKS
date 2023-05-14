output "rg_name" {
  value = azurerm_resource_group.build.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.build.name
}

output "acr_server" {
  value = azurerm_container_registry.build.login_server
}

output "ingress_ip" {
  value = data.external.ingress.result["ip"]
}

output "sql_name" {
  value = azurerm_mssql_server.build.name
}

output "sql_username" {
  value = azurerm_mssql_server.build.administrator_login
}

output "sql_password" {
  value     = azurerm_mssql_server.build.administrator_login_password
  sensitive = true
}

output "sql_db_catalog" {
  value = azurerm_mssql_database.sqldb_catalog.name
}

output "sql_db_identity" {
  value = azurerm_mssql_database.sqldb_identity.name
}

output "aoai_endpoint" {
  value = azurerm_cognitive_account.build.endpoint
}

output "aoai_access_key" {
  value     = azurerm_cognitive_account.build.primary_access_key
  sensitive = true
}

output "aac_connection_string" {
  value     = azurerm_app_configuration.build.primary_write_key[0].connection_string
  sensitive = true
}