variable "nom_projet" {
  type = string
}

variable "groupe" {
  type = string
}

variable "region" {
  type = string
}

variable "tags" {
  type = map(string)
}

# Plan d'adressage (docs/rapport.md, section 5). Ne chevauche ni les Services AKS (10.1.0.0/16),
# ni les pods (192.168.0.0/16).
variable "cidr_vnet" {
  type    = string
  default = "10.0.0.0/16"
}

variable "cidr_aks" {
  type    = string
  default = "10.0.0.0/22"
}

variable "cidr_donnees" {
  type    = string
  default = "10.0.4.0/24"
}
