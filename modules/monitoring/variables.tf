variable "nom_projet" {
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

variable "domaine" {
  description = "Nom de domaine du site, testé par le test de disponibilité."
  type        = string
}

variable "region_alertes" {
  description = "Région des alertes sur journaux : belgiumcentral ne propose pas ce type de ressource."
  type        = string
  default     = "francecentral"
}

variable "budget_mensuel" {
  type = number
}

variable "email_alerte" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
}
