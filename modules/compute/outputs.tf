output "nom" {
  value = azurerm_kubernetes_cluster.principal.name
}

output "oidc_issuer_url" {
  description = "Émetteur des jetons des comptes de service, reconnu par l'identité de l'application."
  value       = azurerm_kubernetes_cluster.principal.oidc_issuer_url
}
