# Tableau de bord : un classeur (workbook) Azure Monitor défini ici, chaque tuile étant une requête KQL sur
# l'espace Log Analytics. Portail Azure > Monitor > Classeurs > « Simplmarket » (lien : terraform output).

locals {
  espace = lower(azurerm_log_analytics_workspace.principal.id)

  # [titre, requête KQL, visualisation]
  tuiles = [
    ["Disponibilité du site (%)", "AppAvailabilityResults | summarize disponibilite = 100.0 * avg(toint(Success)) by bin(TimeGenerated, 15m)", "timechart"],
    ["Requêtes de l'API par code HTTP", "AppRequests | summarize requetes = count() by bin(TimeGenerated, 5m), code = ResultCode", "timechart"],
    ["Temps de réponse de l'API, 95e centile (ms)", "AppRequests | summarize p95 = percentile(DurationMs, 95) by bin(TimeGenerated, 5m)", "timechart"],
    ["Tâches en attente ou en cours (suivies par KEDA)", "AppMetrics | where Name == 'jobs_en_file' | summarize taches = max(Max) by bin(TimeGenerated, 1m)", "timechart"],
    ["Tâches terminées par agent", "AppMetrics | where Name == 'jobs_finis' | summarize taches = sum(Sum) by bin(TimeGenerated, 5m), agent = tostring(Properties.agent)", "timechart"],
    ["Pods de l'application en marche", "KubePodInventory | where Namespace == 'simplmarket' and PodStatus == 'Running' | summarize pods = dcount(Name) by bin(TimeGenerated, 1m), ControllerName", "timechart"],
    ["Nœuds du cluster", "KubeNodeInventory | summarize noeuds = dcount(Computer) by bin(TimeGenerated, 1m)", "timechart"],
    ["CPU par conteneur (millicœurs)", "Perf | where ObjectName == 'K8SContainer' and CounterName == 'cpuUsageNanoCores' | summarize cpu = avg(CounterValue) / 1000000 by bin(TimeGenerated, 1m), conteneur = tostring(split(InstanceName, '/')[-1])", "timechart"],
    ["Avertissements Kubernetes (pannes, redémarrages)", "KubeEvents | where Namespace == 'simplmarket' and KubeEventType == 'Warning' | project TimeGenerated, Objet = Name, Raison = Reason, Message | top 20 by TimeGenerated", "table"],
    ["Livrables archivés dans Blob", "AppDependencies | where Type has 'blob' | summarize archives = count() by bin(TimeGenerated, 1h), succes = Success", "barchart"],
  ]
}

resource "azurerm_application_insights_workbook" "tableau_de_bord" {
  # Le nom d'un classeur est un UUID : celui-ci est fixe, pour garder le même classeur d'un apply à l'autre.
  name                = uuidv5("url", "https://${var.nom_projet}/tableau-de-bord")
  resource_group_name = var.groupe
  location            = var.region
  display_name        = "Simplmarket"
  source_id           = local.espace
  tags                = var.tags

  data_json = jsonencode({
    version             = "Notebook/1.0"
    fallbackResourceIds = [local.espace]
    items = concat(
      [
        {
          type    = 1
          name    = "titre"
          content = { json = "## Simplmarket\nApplication Insights (API, tâches, disponibilité) et Container Insights (pods, nœuds), dans l'espace Log Analytics de l'environnement." }
        },
        {
          type = 9
          name = "parametres"
          content = {
            version = "KqlParameterItem/1.0"
            parameters = [{
              id           = "periode"
              version      = "KqlParameterItem/1.0"
              name         = "Periode"
              label        = "Période"
              type         = 4
              isRequired   = true
              value        = { durationMs = 3600000 }
              typeSettings = { selectableValues = [for ms in [900000, 3600000, 14400000, 86400000] : { durationMs = ms }] }
            }]
          }
        },
      ],
      [for i, t in local.tuiles : {
        type        = 3
        name        = "tuile-${i + 1}"
        customWidth = "50"
        content = {
          version                  = "KqlItem/1.0"
          title                    = t[0]
          query                    = t[1]
          visualization            = t[2]
          size                     = 0
          queryType                = 0
          resourceType             = "microsoft.operationalinsights/workspaces"
          crossComponentResources  = [local.espace]
          timeContextFromParameter = "Periode"
        }
      }],
    )
  })
}
