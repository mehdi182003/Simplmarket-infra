output "workspace_id" {
  value = azurerm_log_analytics_workspace.principal.id
}

output "tableau_de_bord" {
  description = "Lien du classeur dans le portail Azure."
  value       = "https://portal.azure.com/#@/resource${azurerm_application_insights_workbook.tableau_de_bord.id}/workbook"
}
