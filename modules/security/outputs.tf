output "key_vault_nom" {
  value = azurerm_key_vault.coffre.name
}

output "identite_client_id" {
  description = "Identité que prennent les pods de l'application (chart Helm : azure.clientId)."
  value       = azurerm_user_assigned_identity.application.client_id
}

output "tenant_id" {
  value = data.azurerm_client_config.courant.tenant_id
}
