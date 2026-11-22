variable "nom_projet" {
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

variable "acr_id" {
  type = string
}

variable "workspace_id" {
  description = "Espace Log Analytics qui reçoit les données de Container Insights."
  type        = string
}

variable "ips_admin" {
  description = "Adresses autorisées à joindre l'API Kubernetes (CIDR)."
  type        = list(string)
  sensitive   = true
}

variable "espace_application" {
  description = "Espace de noms Kubernetes de l'application, le seul dont les journaux sont collectés."
  type        = string
  default     = "simplmarket"
}

variable "tags" {
  type = map(string)
}
