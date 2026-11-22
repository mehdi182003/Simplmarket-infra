# Simplmarket : infrastructure Azure

Infrastructure as Code (Terraform) de [Simplmarket](https://github.com/galile0-24/Simplmarket), une agence
marketing animée par des agents IA, déployée sur Azure (abonnement Azure for Students).

- **Rapport de rendu : [docs/rapport.md](docs/rapport.md)** (architecture, choix, coûts, limites).
- Le code de l'application, ses images Docker, son chart Helm et son pipeline sont dans le dépôt de l'application.

## Ce que crée `terraform apply`

| Module | Ressources |
|---|---|
| `modules/network` | VNet `10.0.0.0/16`, sous-réseaux `snet-aks` et `snet-donnees`, un NSG par sous-réseau, zone DNS privée de PostgreSQL |
| `modules/storage` | Azure Container Registry, compte de stockage Blob (livrables, cycle de vie), PostgreSQL flexible avec point de terminaison privé |
| `modules/compute` | Cluster AKS (autoscaler, KEDA, Workload Identity, pilote CSI de Key Vault, Container Insights), droit AcrPull |
| `modules/security` | Key Vault et ses secrets, identité managée de l'application, rôles RBAC, Policy des tags obligatoires |
| `modules/monitoring` | Log Analytics, Application Insights, test de disponibilité, 4 alertes, budget, tableau de bord |

Tags `owner`, `project` et `environment` sur chaque ressource, imposés par une Policy.

## Structure

```
.
├── backend.tf               remote state (Blob privé, verrou par bail, authentification Entra ID)
├── provider.tf              azurerm, azapi, random
├── variables.tf             toutes les variables, documentées
├── main.tf                  groupe de ressources et appel des 5 modules
├── outputs.tf               URL, groupe, registre, cluster, coffre, tableau de bord…
├── prod.tfvars              configuration de l'environnement prod (versionnée, sans secret)
├── terraform.tfvars.example modèle des valeurs secrètes (terraform.tfvars, jamais versionné)
├── modules/                 network, storage, compute, security, monitoring
├── docs/                    rapport, schémas draw.io, captures d'écran
└── .github/workflows/ci.yml fmt, validate, Gitleaks, puis apply à chaque fusion dans main
```

## Déployer depuis zéro

Prérequis : Azure CLI, Terraform ≥ 1.9.8, un abonnement Azure (testé sur Azure for Students).

### 1. Une seule fois : le stockage du state

C'est la seule ressource créée à la main, puisque Terraform a besoin de ce stockage avant de pouvoir créer quoi que
ce soit. Remplacer `<suffixe>` par le sien et reporter le nom du compte dans `backend.tf`.

```bash
az group create -n rg-simplmarket-tfstate -l belgiumcentral --tags owner=<vous> project=simplmarket environment=prod
az storage account create -n sttfsimplmarket<suffixe> -g rg-simplmarket-tfstate --sku Standard_LRS \
  --allow-shared-key-access false --allow-blob-public-access false --min-tls-version TLS1_2
az storage account blob-service-properties update -n sttfsimplmarket<suffixe> -g rg-simplmarket-tfstate \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 30
az storage container create -n tfstate --account-name sttfsimplmarket<suffixe> --auth-mode login
az role assignment create --role "Storage Blob Data Contributor" \
  --assignee "$(az ad signed-in-user show --query id -o tsv)" \
  --scope "$(az storage account show -n sttfsimplmarket<suffixe> --query id -o tsv)"
```

Le state contient des données sensibles : il n'est accessible qu'avec une identité Entra ID autorisée, sans clé.
Le versionnage garde ses anciennes versions 30 jours. Terraform pose un bail sur le Blob pendant chaque opération,
ce qui empêche deux `apply` simultanés (verrouillage).

### 2. Les valeurs secrètes

```bash
cp terraform.tfvars.example terraform.tfvars   # puis le compléter : abonnement, e-mail, clé Gemini, adresses
```

`terraform.tfvars` est exclu de Git. `prod.tfvars`, versionné, ne contient que la configuration non sensible.

### 3. L'infrastructure

```bash
terraform init
terraform apply -var-file=prod.tfvars     # environ 12 min
terraform output                          # URL du site, registre, cluster, lien du tableau de bord…
```

### 4. L'application

Dans le dépôt de l'application : Actions > ci > **Run workflow** sur `main`. Le pipeline construit les deux images
avec Docker, les pousse dans ACR, puis installe le chart Helm dans AKS. Le site répond ensuite sur `url_site`.

## Détruire

```bash
terraform destroy -var-file=prod.tfvars   # environ 10 min ; seul reste le groupe du state
```

Le coffre est purgé à la destruction : son nom est immédiatement réutilisable. Rien d'autre n'est facturé ensuite,
sauf le state (quelques centimes par mois).

## Déploiement continu (GitHub Actions)

| Job | Quand | Rôle |
|---|---|---|
| `terraform` | chaque push et pull request | `terraform fmt -check`, `init -backend=false`, `validate` |
| `secrets` | idem | Gitleaks sur tout l'historique |
| `deploy` | fusion dans `main`, ou « Run workflow » | `terraform apply -var-file=prod.tfvars`, seulement si l'environnement existe |

`main` est protégée : une pull request ne peut être fusionnée que si `terraform` et `secrets` sont verts.

Le job `deploy` se connecte à Azure par OIDC, sans mot de passe stocké, avec l'identité managée
`id-github-simplmarket` (groupe du state), qui n'accepte que la branche `main`. Il est actif quand la variable
`DEPLOIEMENT_CONTINU` vaut `true`. Après un `terraform destroy`, une fusion ne recrée rien.

Mise en place, une fois. Le sujet OIDC contient les numéros du compte et du dépôt : le message d'erreur d'Azure le
donne en entier s'il diffère.

```bash
az identity federated-credential create -g rg-simplmarket-tfstate --identity-name id-github-simplmarket \
  -n infra-main --issuer https://token.actions.githubusercontent.com --audiences api://AzureADTokenExchange \
  --subject "repo:<compte>/Simplmarket-infra:ref:refs/heads/main"
```

Droits de cette identité : Contributor sur l'abonnement, Storage Blob Data Contributor sur le compte du state, et
Role Based Access Control Administrator limité aux 3 rôles que Terraform attribue (AcrPull, Key Vault Secrets User,
Storage Blob Data Contributor). Secrets du dépôt : `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`EMAIL_ALERTE`, `GEMINI_API_KEY`, `IPS_ADMIN` (par exemple `["203.0.113.10/32"]`) ; variable :
`DEPLOIEMENT_CONTINU`.
