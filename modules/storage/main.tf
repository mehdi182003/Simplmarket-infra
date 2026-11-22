# Cours 2 : deux stockages aux usages différents, et le registre des images.
#   PostgreSQL : données relationnelles de l'application (tâches, profil de marque), lues et écrites sans cesse.
#   Blob       : livrables approuvés, archivés une fois puis rarement relus : cycle de vie vers les niveaux froids.

resource "azurerm_container_registry" "images" {
  name                = "acr${var.nom_projet}${var.suffixe}"
  resource_group_name = var.groupe
  location            = var.region
  sku                 = "Basic"
  # Pas de compte partagé : AKS tire les images avec son identité, le pipeline pousse avec la sienne.
  admin_enabled = false
  tags          = var.tags
}

# Réplication ZRS : 3 copies dans 3 zones de la région, comme les nœuds AKS. Les livrables survivent à la perte
# d'une zone, pour environ 25 % de plus que LRS. GRS (autre région) serait excessif pour des documents archivés.
resource "azurerm_storage_account" "livrables" {
  name                     = "st${var.nom_projet}${var.suffixe}"
  resource_group_name      = var.groupe
  location                 = var.region
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "ZRS"
  access_tier              = "Hot"

  # Accès uniquement par Entra ID (identité managée), en HTTPS récent, jamais anonyme.
  shared_access_key_enabled        = false
  default_to_oauth_authentication  = true
  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
  https_traffic_only_enabled       = true
  min_tls_version                  = "TLS1_2"

  # Seuls les nœuds AKS et les administrateurs atteignent les données.
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.subnet_aks_id]
    # Le stockage refuse les préfixes /32 : il attend l'adresse seule.
    ip_rules = [for ip in var.ips_admin : trimsuffix(ip, "/32")]
  }

  # Un livrable supprimé par erreur reste récupérable 7 jours.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

resource "azurerm_storage_container" "livrables" {
  name                  = "livrables"
  storage_account_id    = azurerm_storage_account.livrables.id
  container_access_type = "private"
}

# Un livrable n'est presque plus relu après un mois : niveau froid, puis plus froid encore, puis suppression.
# Le niveau Archive n'existe pas en ZRS.
resource "azurerm_storage_management_policy" "livrables" {
  storage_account_id = azurerm_storage_account.livrables.id

  rule {
    name    = "cycle-de-vie-livrables"
    enabled = true

    filters {
      blob_types   = ["blockBlob"]
      prefix_match = ["${azurerm_storage_container.livrables.name}/"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than = 30
        tier_to_cold_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than       = 365
      }
    }
  }
}

resource "random_password" "postgres" {
  length  = 32
  special = false
  # Toutes les classes de caractères exigées par Azure, sans caractère à échapper dans une URL.
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
}

resource "azurerm_postgresql_flexible_server" "principal" {
  name                = "pg-${var.nom_projet}-${var.suffixe}"
  resource_group_name = var.groupe
  location            = var.region
  version             = "16"
  # La plus petite taille : 1 vCPU partagé, 2 Go, 50 connexions.
  sku_name = "B_Standard_B1ms"

  # Aucun accès public : la base n'est joignable que par son point de terminaison privé, dans le VNet.
  public_network_access_enabled = false

  administrator_login    = var.utilisateur
  administrator_password = random_password.postgres.result

  storage_mb        = 32768
  auto_grow_enabled = true
  # Sauvegardes automatiques (restauration à un instant donné sur 7 jours), dans la région de la base.
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = var.tags

  lifecycle {
    # Azure choisit la zone selon sa capacité : ne pas recréer le serveur pour autant.
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "agence" {
  name      = var.base
  server_id = azurerm_postgresql_flexible_server.principal.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Le point de terminaison privé donne à la base une adresse du sous-réseau des données : elle n'est joignable que
# depuis le VNet, et le NSG de ce sous-réseau filtre qui peut l'atteindre.
resource "azurerm_private_endpoint" "postgres" {
  name                = "pe-${azurerm_postgresql_flexible_server.principal.name}"
  resource_group_name = var.groupe
  location            = var.region
  subnet_id           = var.subnet_donnees_id
  tags                = var.tags

  private_service_connection {
    name                           = "postgres"
    private_connection_resource_id = azurerm_postgresql_flexible_server.principal.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "postgres"
    private_dns_zone_ids = [var.zone_dns_postgres_id]
  }
}
