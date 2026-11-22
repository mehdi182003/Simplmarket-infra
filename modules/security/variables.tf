variable "nom_projet" {
  type = string
}

variable "suffixe" {
  type = string
}

variable "groupe" {
  type = string
}

variable "groupe_id" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_aks_id" {
  type = string
}

variable "ips_admin" {
  type      = list(string)
  sensitive = true
}

variable "oidc_issuer_url" {
  type = string
}

variable "conteneur_livrables_id" {
  type = string
}

variable "secrets" {
  description = "Secrets de l'application, par nom dans le coffre."
  type        = map(string)
  sensitive   = true
}

variable "tags_obligatoires" {
  description = "Tags que la Policy exige sur chaque ressource du groupe."
  type        = list(string)
}

variable "tags" {
  type = map(string)
}

# Compte de service Kubernetes autorisé à prendre l'identité de l'application (chart Helm du dépôt de l'application).
variable "espace_application" {
  type    = string
  default = "simplmarket"
}

variable "compte_de_service" {
  type    = string
  default = "simplmarket"
}
