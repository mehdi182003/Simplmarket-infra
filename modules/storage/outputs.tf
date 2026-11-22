output "acr_id" {
  value = azurerm_container_registry.images.id
}

output "acr_nom" {
  value = azurerm_container_registry.images.name
}

output "conteneur_livrables_id" {
  value = azurerm_storage_container.livrables.id
}

output "postgres_nom" {
  value = azurerm_postgresql_flexible_server.principal.name
}

locals {
  # Résolu vers l'adresse privée par la zone DNS du VNet.
  serveur = azurerm_postgresql_flexible_server.principal.fqdn
  base    = azurerm_postgresql_flexible_server_database.agence.name
}

output "database_url" {
  description = "Connexion de l'application : TLS obligatoire."
  value       = "postgresql+asyncpg://${var.utilisateur}:${random_password.postgres.result}@${local.serveur}:5432/${local.base}?ssl=require"
  sensitive   = true
}

output "keda_pg_connection" {
  description = "Connexion au format libpq, pour le scaler PostgreSQL de KEDA."
  value       = "host=${local.serveur} port=5432 user=${var.utilisateur} password=${random_password.postgres.result} dbname=${local.base} sslmode=require"
  sensitive   = true
}
