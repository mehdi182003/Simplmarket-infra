# terraform apply -var-file=prod.tfvars crée toutes les ressources Azure de l'environnement.
# L'application (images et Kubernetes) est déployée par le pipeline de son propre dépôt.

locals {
  # Gouvernance : tags obligatoires sur chaque ressource, imposés par une Policy (modules/security).
  tags = {
    owner       = var.owner
    project     = var.nom_projet
    environment = var.environnement
  }
  # Nom DNS gratuit, posé par AKS sur l'IP du load balancer : https://<etiquette>.<région>.cloudapp.azure.com
  etiquette_dns = "${var.nom_projet}-${var.suffixe}"
  domaine       = "${local.etiquette_dns}.${var.region}.cloudapp.azure.com"
}

resource "azurerm_resource_group" "principal" {
  name     = "rg-${var.nom_projet}"
  location = var.region
  tags     = local.tags
}

module "network" {
  source = "./modules/network"

  nom_projet = var.nom_projet
  groupe     = azurerm_resource_group.principal.name
  region     = var.region
  tags       = local.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  nom_projet     = var.nom_projet
  groupe         = azurerm_resource_group.principal.name
  groupe_id      = azurerm_resource_group.principal.id
  region         = var.region
  domaine        = local.domaine
  budget_mensuel = var.budget_mensuel
  email_alerte   = var.email_alerte
  tags           = local.tags
}

module "storage" {
  source = "./modules/storage"

  nom_projet           = var.nom_projet
  suffixe              = var.suffixe
  groupe               = azurerm_resource_group.principal.name
  region               = var.region
  subnet_aks_id        = module.network.subnet_aks_id
  subnet_donnees_id    = module.network.subnet_donnees_id
  zone_dns_postgres_id = module.network.zone_dns_postgres_id
  ips_admin            = var.ips_admin
  tags                 = local.tags
}

module "compute" {
  source = "./modules/compute"

  nom_projet    = var.nom_projet
  groupe        = azurerm_resource_group.principal.name
  region        = var.region
  subnet_aks_id = module.network.subnet_aks_id
  acr_id        = module.storage.acr_id
  workspace_id  = module.monitoring.workspace_id
  ips_admin     = var.ips_admin
  tags          = local.tags
}

module "security" {
  source = "./modules/security"

  nom_projet             = var.nom_projet
  suffixe                = var.suffixe
  groupe                 = azurerm_resource_group.principal.name
  groupe_id              = azurerm_resource_group.principal.id
  region                 = var.region
  subnet_aks_id          = module.network.subnet_aks_id
  ips_admin              = var.ips_admin
  oidc_issuer_url        = module.compute.oidc_issuer_url
  conteneur_livrables_id = module.storage.conteneur_livrables_id
  tags_obligatoires      = keys(local.tags)
  tags                   = local.tags

  # Noms lus par l'application (SecretProviderClass du chart Helm).
  secrets = {
    database-url       = module.storage.database_url
    keda-pg-connection = module.storage.keda_pg_connection
    gemini-api-key     = var.gemini_api_key
  }
}
