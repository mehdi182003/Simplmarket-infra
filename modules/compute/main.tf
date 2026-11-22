# Cours 3 : conteneurs orchestrés par AKS, élasticité des pods et des nœuds, coût réduit au minimum.

resource "azurerm_kubernetes_cluster" "principal" {
  name                = "aks-${var.nom_projet}"
  resource_group_name = var.groupe
  location            = var.region
  dns_prefix          = "aks-${var.nom_projet}"
  # Plan de contrôle gratuit.
  sku_tier = "Free"

  default_node_pool {
    name = "sys"
    # La moins chère des VM autorisées par l'abonnement étudiant (pas de série B).
    vm_size = "Standard_D2as_v4"
    # Le 2e nœud n'existe que pendant les pics : le quota de l'abonnement s'arrête à 2.
    auto_scaling_enabled = true
    min_count            = 1
    max_count            = 2
    zones                = ["1", "2", "3"]
    vnet_subnet_id       = var.subnet_aks_id
    # AKS réserve de la mémoire en proportion du nombre de pods possibles (250 par défaut).
    max_pods = 60
    # Disque sur le cache local de la VM : gratuit, plus rapide, et les nœuds n'ont aucun état à garder.
    os_disk_type    = "Ephemeral"
    os_disk_size_gb = 48
    # Nom temporaire exigé par Azure pour remplacer le pool lors d'un changement de taille.
    temporary_name_for_rotation = "systemp"
    tags                        = var.tags

    # Mise à jour d'un nœud : un nœud de plus le temps de déplacer les pods.
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  # Réseau des pods et NetworkPolicies, appliquées par Cilium.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "10.1.0.0/16"
    dns_service_ip      = "10.1.0.10"
  }

  # Moindre privilège : l'API Kubernetes n'est joignable que depuis les adresses des administrateurs.
  # Le pipeline de l'application passe par Azure Resource Manager (az aks command invoke), pas par Internet.
  api_server_access_profile {
    authorized_ip_ranges = var.ips_admin
  }

  # Identités de charge (cours 6) : un pod reçoit un jeton Entra ID pour son compte de service, sans secret.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # Pilote CSI du coffre : les secrets de Key Vault deviennent un Secret Kubernetes, relu toutes les 2 minutes.
  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  # Container Insights : journaux, inventaire et performances des conteneurs vers Log Analytics.
  oms_agent {
    log_analytics_workspace_id      = var.workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  auto_scaler_profile {
    # Un nœud inutile est rendu après 5 minutes (10 par défaut).
    scale_down_unneeded        = "5m"
    scale_down_delay_after_add = "5m"
    # Sinon un seul pod système ou un emptyDir suffit à garder le 2e nœud allumé, et à doubler le prix de la VM.
    skip_nodes_with_system_pods   = false
    skip_nodes_with_local_storage = false
  }

  # KEDA : mise à l'échelle des workers selon le nombre de tâches.
  workload_autoscaler_profile {
    keda_enabled = true
  }

  # Correctifs de sécurité automatiques.
  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  tags = var.tags
}

# AKS tire les images avec son identité, sans mot de passe.
resource "azurerm_role_assignment" "pull_images" {
  scope                            = var.acr_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.principal.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# Ce que Container Insights collecte : seulement l'espace de noms de l'application, pour limiter le volume
# (et donc le coût) des journaux. Les données des nœuds sont toujours collectées.
resource "azurerm_monitor_data_collection_rule" "conteneurs" {
  name                = "dcr-${var.nom_projet}-conteneurs"
  resource_group_name = var.groupe
  location            = var.region
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "journaux"
      workspace_resource_id = var.workspace_id
    }
  }

  data_flow {
    streams      = ["Microsoft-ContainerInsights-Group-Default"]
    destinations = ["journaux"]
  }

  data_sources {
    extension {
      name           = "ContainerInsightsExtension"
      extension_name = "ContainerInsights"
      streams        = ["Microsoft-ContainerInsights-Group-Default"]
      extension_json = jsonencode({
        dataCollectionSettings = {
          interval               = "1m"
          namespaceFilteringMode = "Include"
          namespaces             = [var.espace_application]
          enableContainerLogV2   = true
        }
      })
    }
  }
}

resource "azurerm_monitor_data_collection_rule_association" "conteneurs" {
  name                    = "ContainerInsightsExtension"
  target_resource_id      = azurerm_kubernetes_cluster.principal.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.conteneurs.id
}
