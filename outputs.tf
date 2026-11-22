output "url_site" {
  description = "Adresse publique de l'application (une fois déployée par le pipeline de son dépôt)."
  value       = "https://${local.domaine}"
}

output "groupe" {
  description = "Groupe de ressources de l'environnement."
  value       = azurerm_resource_group.principal.name
}

output "registre" {
  description = "Registre des images (Azure Container Registry)."
  value       = module.storage.acr_nom
}

output "aks" {
  description = "Nom du cluster AKS."
  value       = module.compute.nom
}

output "kubectl" {
  description = "Connexion de kubectl au cluster, depuis une adresse de ips_admin."
  value       = "az aks get-credentials -g ${azurerm_resource_group.principal.name} -n ${module.compute.nom}"
}

output "key_vault" {
  description = "Coffre des secrets de l'application."
  value       = module.security.key_vault_nom
}

output "identite_application" {
  description = "Client ID de l'identité managée des pods (Workload Identity)."
  value       = module.security.identite_client_id
}

output "postgres" {
  description = "Serveur PostgreSQL, joignable uniquement depuis le VNet."
  value       = module.storage.postgres_nom
}

output "tableau_de_bord" {
  description = "Tableau de bord Azure Monitor."
  value       = module.monitoring.tableau_de_bord
}
