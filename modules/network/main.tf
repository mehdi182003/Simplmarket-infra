# Cours 4 : un VNet, un sous-réseau par niveau (application, données), un NSG par sous-réseau au moindre privilège.

resource "azurerm_virtual_network" "principal" {
  name                = "vnet-${var.nom_projet}"
  resource_group_name = var.groupe
  location            = var.region
  address_space       = [var.cidr_vnet]
  tags                = var.tags
}

# Nœuds AKS. Le coffre et le stockage n'acceptent que ce sous-réseau (et les administrateurs) :
# les points de service gardent ce trafic sur le réseau d'Azure.
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = var.groupe
  virtual_network_name = azurerm_virtual_network.principal.name
  address_prefixes     = [var.cidr_aks]
  service_endpoints    = ["Microsoft.KeyVault", "Microsoft.Storage"]
}

# Données : le point de terminaison privé de PostgreSQL, soumis au NSG ci-dessous.
resource "azurerm_subnet" "donnees" {
  name                              = "snet-donnees"
  resource_group_name               = var.groupe
  virtual_network_name              = azurerm_virtual_network.principal.name
  address_prefixes                  = [var.cidr_donnees]
  private_endpoint_network_policies = "Enabled"
}

# Seul le web (80 et 443) entre depuis Internet. Le reste est refusé par les règles par défaut d'Azure.
# La destination reste « * » : le load balancer d'AKS garde l'IP publique comme destination des paquets
# (floating IP), qui n'est donc pas une adresse du sous-réseau.
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-snet-aks"
  resource_group_name = var.groupe
  location            = var.region
  tags                = var.tags

  security_rule {
    name                       = "autoriser-web-depuis-internet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

# Uniquement PostgreSQL, uniquement depuis les nœuds AKS.
resource "azurerm_network_security_group" "donnees" {
  name                = "nsg-snet-donnees"
  resource_group_name = var.groupe
  location            = var.region
  tags                = var.tags

  security_rule {
    name                       = "autoriser-postgres-depuis-aks"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = var.cidr_aks
    destination_address_prefix = var.cidr_donnees
  }

  security_rule {
    name                       = "refuser-tout-le-reste"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "donnees" {
  subnet_id                 = azurerm_subnet.donnees.id
  network_security_group_id = azurerm_network_security_group.donnees.id
}

# Dans le VNet, le nom public de la base pointe vers l'adresse privée de son point de terminaison.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.groupe
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "lien-${azurerm_virtual_network.principal.name}"
  resource_group_name   = var.groupe
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.principal.id
  tags                  = var.tags
}
