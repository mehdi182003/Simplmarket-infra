# Environnement prod : versionné, sans aucun secret.
# Les valeurs secrètes ou personnelles sont dans terraform.tfvars (voir terraform.tfvars.example).

environnement = "prod"
owner         = "mehdi"
# Rend uniques les noms globaux : https://simplmarket-wolxoj.belgiumcentral.cloudapp.azure.com
suffixe = "wolxoj"

region         = "belgiumcentral"
budget_mensuel = 10
