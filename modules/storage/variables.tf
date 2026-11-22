variable "nom_projet" {
  type = string
}

variable "suffixe" {
  type = string
}

variable "groupe" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_aks_id" {
  type = string
}

variable "subnet_donnees_id" {
  type = string
}

variable "zone_dns_postgres_id" {
  type = string
}

variable "ips_admin" {
  type      = list(string)
  sensitive = true
}

variable "tags" {
  type = map(string)
}

variable "utilisateur" {
  type    = string
  default = "agence"
}

variable "base" {
  type    = string
  default = "agence"
}
