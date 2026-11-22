terraform {
  required_version = ">= 1.9.8"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    # Écrit les secrets du coffre par Azure Resource Manager (voir modules/security).
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  # Uniquement les services utilisés : l'abonnement étudiant refuse d'en enregistrer certains autres.
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Authorization",
    "Microsoft.Compute",
    "Microsoft.Consumption",
    "Microsoft.ContainerRegistry",
    "Microsoft.ContainerService",
    "Microsoft.DBforPostgreSQL",
    "Microsoft.Insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.Storage",
  ]
  # Le compte de stockage refuse les clés partagées : Terraform s'authentifie par Entra ID.
  storage_use_azuread = true

  features {
    # Un coffre détruit est purgé : sinon son nom reste réservé 7 jours et bloque le redéploiement.
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    # Terraform ne passe que par Azure Resource Manager : le pare-feu du compte de stockage ne le bloque pas.
    storage {
      data_plane_available = false
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}
