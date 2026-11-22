output "subnet_aks_id" {
  value = azurerm_subnet.aks.id
  # Le cluster attend que le NSG soit posé sur son sous-réseau.
  depends_on = [azurerm_subnet_network_security_group_association.aks]
}

output "subnet_donnees_id" {
  value      = azurerm_subnet.donnees.id
  depends_on = [azurerm_subnet_network_security_group_association.donnees]
}

output "zone_dns_postgres_id" {
  value = azurerm_private_dns_zone.postgres.id
  # Le nom de la base n'est résolu dans le VNet qu'une fois la zone liée.
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}
