# Cours 6 : supervision par Azure Monitor. Les traces de l'application (Application Insights) et des conteneurs
# (Container Insights) arrivent dans le même espace Log Analytics, qu'interrogent les alertes et le tableau de bord.

resource "azurerm_log_analytics_workspace" "principal" {
  name                = "log-${var.nom_projet}"
  resource_group_name = var.groupe
  location            = var.region
  sku                 = "PerGB2018"
  # 30 jours sont inclus dans le prix ; les 5 premiers Go du mois sont gratuits.
  retention_in_days = 30
  # Plafond de sécurité : au-delà de 0,5 Go par jour, la collecte s'arrête jusqu'au lendemain.
  daily_quota_gb = 0.5
  tags           = var.tags
}

resource "azurerm_application_insights" "principal" {
  name                = "appi-${var.nom_projet}"
  resource_group_name = var.groupe
  location            = var.region
  workspace_id        = azurerm_log_analytics_workspace.principal.id
  application_type    = "web"
  tags                = var.tags
}

# Disponibilité vue de l'extérieur : depuis 2 villes, toutes les 15 minutes, le site doit répondre 200 sur
# /api/marque, qui traverse tout le chemin (Traefik, nginx, API, PostgreSQL), avec un certificat valide.
resource "azurerm_application_insights_standard_web_test" "disponibilite" {
  name                    = "disponibilite-site"
  resource_group_name     = var.groupe
  location                = var.region
  application_insights_id = azurerm_application_insights.principal.id
  geo_locations           = ["emea-nl-ams-azr", "emea-fr-pra-edge"]
  frequency               = 900
  timeout                 = 30
  # Désactivé par défaut dans le fournisseur Terraform.
  enabled = true
  # Un échec isolé est retenté avant d'être compté.
  retry_enabled = true
  tags          = var.tags

  request {
    url = "https://${var.domaine}/api/marque"
  }

  validation_rules {
    expected_status_code        = 200
    ssl_check_enabled           = true
    ssl_cert_remaining_lifetime = 7
  }
}

resource "azurerm_monitor_action_group" "equipe" {
  name                = "ag-${var.nom_projet}"
  resource_group_name = var.groupe
  short_name          = var.nom_projet
  tags                = var.tags

  email_receiver {
    name                    = "equipe"
    email_address           = var.email_alerte
    use_common_alert_schema = true
  }
}

# --- Alertes : disponibilité, erreurs 5xx, latence (et budget, plus bas) ----------------------------------------

resource "azurerm_monitor_metric_alert" "disponibilite" {
  name                = "site-indisponible"
  description         = "Le site ne répond pas correctement depuis au moins une ville."
  resource_group_name = var.groupe
  scopes              = [azurerm_application_insights_standard_web_test.disponibilite.id, azurerm_application_insights.principal.id]
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = var.tags

  application_insights_web_test_location_availability_criteria {
    web_test_id           = azurerm_application_insights_standard_web_test.disponibilite.id
    component_id          = azurerm_application_insights.principal.id
    failed_location_count = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.equipe.id
  }
}

locals {
  # Requêtes KQL sur les requêtes HTTP que l'API envoie à Application Insights.
  alertes_journaux = {
    erreurs-5xx = {
      description = "Plus de 5 réponses HTTP 5xx de l'API en 5 minutes."
      severite    = 2
      requete     = "AppRequests | where ResultCode startswith '5'"
      agregation  = "Count"
      colonne     = null
      seuil       = 5
    }
    latence-elevee = {
      description = "Temps de réponse moyen de l'API au-dessus de 2 secondes sur 5 minutes."
      severite    = 3
      requete     = "AppRequests"
      agregation  = "Average"
      colonne     = "DurationMs"
      seuil       = 2000
    }
  }
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "journaux" {
  for_each = local.alertes_journaux

  name                = each.key
  description         = each.value.description
  resource_group_name = var.groupe
  # Ce type de règle n'existe pas dans la région de l'environnement ; elle interroge quand même son espace.
  location             = var.region_alertes
  scopes               = [azurerm_log_analytics_workspace.principal.id]
  severity             = each.value.severite
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"
  tags                 = var.tags

  criteria {
    query                   = each.value.requete
    time_aggregation_method = each.value.agregation
    metric_measure_column   = each.value.colonne
    operator                = "GreaterThan"
    threshold               = each.value.seuil

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.equipe.id]
  }
}

# Service mesuré (cours 1) : prévenu tôt si un environnement a été oublié allumé.
resource "azurerm_consumption_budget_resource_group" "principal" {
  name              = "budget-${var.nom_projet}"
  resource_group_id = var.groupe_id
  amount            = var.budget_mensuel
  time_grain        = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThan"
      contact_groups = [azurerm_monitor_action_group.equipe.id]
    }
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
