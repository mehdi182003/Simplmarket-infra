# Remote state (cours 5) : un Blob privé, avec verrou (bail du Blob) pendant chaque opération, accessible
# uniquement avec une identité Entra ID autorisée, jamais avec une clé. Créé une fois à la main (README, étape 1).
terraform {
  backend "azurerm" {
    storage_account_name = "sttfsimplmarketwolxoj"
    container_name       = "tfstate"
    key                  = "prod.tfstate"
    use_azuread_auth     = true
  }
}
