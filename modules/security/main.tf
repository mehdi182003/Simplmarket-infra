# Cours 6 : secrets dans Key Vault, identité managée de l'application, RBAC au moindre privilège, Policy des tags.

data "azurerm_client_config" "courant" {}

# --- Secrets ---------------------------------------------------------------------------------------------------

resource "azurerm_key_vault" "coffre" {
  name                = "kv-${var.nom_projet}-${var.suffixe}"
  resource_group_name = var.groupe
  location            = var.region
  tenant_id           = data.azurerm_client_config.courant.tenant_id
  sku_name            = "standard"
  # Droits donnés par des rôles Azure (RBAC), pas par des stratégies d'accès.
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  # Sans protection contre la purge : terraform destroy doit pouvoir libérer le nom (environnement étudiant).
  purge_protection_enabled = false

  # Seuls les nœuds AKS (pilote CSI) et les administrateurs lisent les secrets.
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.subnet_aks_id]
    ip_rules                   = var.ips_admin
  }

  tags = var.tags
}

# Écrits par Azure Resource Manager, que le pare-feu du coffre ne filtre pas : Terraform et le pipeline déposent
# les secrets avec le seul rôle Contributor, sans jamais avoir le droit de les relire.
resource "azapi_resource" "secret" {
  for_each = nonsensitive(toset(keys(var.secrets)))

  type      = "Microsoft.KeyVault/vaults/secrets@2023-07-01"
  name      = each.key
  parent_id = azurerm_key_vault.coffre.id
  body      = { properties = { value = var.secrets[each.key] } }
  tags      = var.tags
}

# --- Identité de l'application ---------------------------------------------------------------------------------

# Les pods de l'application l'utilisent sans aucun secret : Entra ID fait confiance aux jetons que le cluster
# signe pour leur compte de service (Workload Identity).
resource "azurerm_user_assigned_identity" "application" {
  name                = "id-${var.nom_projet}-app"
  resource_group_name = var.groupe
  location            = var.region
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "application" {
  name                      = "kubernetes-${var.espace_application}"
  user_assigned_identity_id = azurerm_user_assigned_identity.application.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.oidc_issuer_url
  subject                   = "system:serviceaccount:${var.espace_application}:${var.compte_de_service}"
}

# Moindre privilège : lire les secrets de ce coffre, écrire dans ce seul conteneur. Rien d'autre.
resource "azurerm_role_assignment" "application" {
  for_each = {
    "Key Vault Secrets User"        = azurerm_key_vault.coffre.id
    "Storage Blob Data Contributor" = var.conteneur_livrables_id
  }

  scope                            = each.value
  role_definition_name             = each.key
  principal_id                     = azurerm_user_assigned_identity.application.principal_id
  skip_service_principal_aad_check = true
}

# --- Gouvernance ------------------------------------------------------------------------------------------------

data "azurerm_policy_definition" "tag_obligatoire" {
  display_name = "Require a tag on resources"
}

# Une ressource sans l'un des tags obligatoires est refusée dans le groupe.
resource "azurerm_resource_group_policy_assignment" "tag" {
  for_each = toset(var.tags_obligatoires)

  name                 = "tag-${each.key}-obligatoire"
  display_name         = "Tag ${each.key} obligatoire"
  resource_group_id    = var.groupe_id
  policy_definition_id = data.azurerm_policy_definition.tag_obligatoire.id
  parameters           = jsonencode({ tagName = { value = each.key } })

  non_compliance_message {
    content = "Chaque ressource doit porter le tag ${each.key}."
  }

  # Exception : Azure crée lui-même, sans tags, la carte réseau du point de terminaison privé.
  resource_selectors {
    name = "sauf-cartes-reseau-creees-par-azure"
    selectors {
      kind   = "resourceType"
      not_in = ["Microsoft.Network/networkInterfaces"]
    }
  }
}
