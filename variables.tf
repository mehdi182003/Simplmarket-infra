# Valeurs de l'environnement : prod.tfvars (versionné, sans secret).
# Valeurs secrètes ou personnelles : terraform.tfvars (jamais versionné, voir terraform.tfvars.example).

variable "subscription_id" {
  description = "Abonnement Azure (az account show --query id -o tsv)."
  type        = string
  sensitive   = true
}

variable "nom_projet" {
  description = "Nom du projet : tag project et nom des ressources."
  type        = string
  default     = "simplmarket"
}

variable "environnement" {
  description = "Nom de l'environnement : tag environment."
  type        = string
}

variable "owner" {
  description = "Responsable des ressources : tag owner."
  type        = string
}

variable "suffixe" {
  description = "Suffixe des noms qui doivent être uniques dans tout Azure (registre, coffre, stockage, base, DNS)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,8}$", var.suffixe))
    error_message = "Le suffixe doit contenir de 3 à 8 lettres minuscules ou chiffres."
  }
}

# Azure for Students n'autorise que 5 régions, et ne propose pas les mêmes services dans chacune.
variable "region" {
  description = "Région de l'environnement : la seule où l'abonnement a une petite VM AKS et une petite base."
  type        = string
}

variable "budget_mensuel" {
  description = "Budget mensuel en dollars : alerte à 50, 80 et 100 %."
  type        = number
}

variable "ips_admin" {
  description = "Adresses publiques (CIDR) des administrateurs : seules autorisées sur l'API Kubernetes, le coffre et le stockage."
  type        = list(string)
  sensitive   = true

  # Pour AKS, une liste vide veut dire « ouvert à tout Internet ».
  validation {
    condition     = length(var.ips_admin) > 0
    error_message = "Au moins une adresse est obligatoire : une liste vide ouvrirait l'API Kubernetes à tout Internet."
  }
}

variable "email_alerte" {
  description = "Adresse qui reçoit les alertes."
  type        = string
  sensitive   = true
}

variable "gemini_api_key" {
  description = "Clé de l'API Gemini, rangée dans le coffre."
  type        = string
  sensitive   = true
}
