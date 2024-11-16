terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
     version = "3.83.0"
    }
  }
}

#https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret
provider "azurerm" {
  features {} 
    skip_provider_registration = true
    client_id = "c26c3f06-e295-4de2-9b68-dc25d0df129e"
    tenant_id = "a7f2b795-a6ea-4a1a-87b2-1a2d5c24f3f7"
    subscription_id = "cbb953b9-6a3c-4f5d-80f8-e5b3fc403eb9"
   # client_secret = var.client_secret
}

resource "azurerm_resource_group" "aks_group1" {
  name     = "aks-group1"
  location = "Centralus"
}

resource "azurerm_kubernetes_cluster" "aks_cluster" {
  name                = "aks-cluster2"
  location            = azurerm_resource_group.aks_group1.location
  resource_group_name = azurerm_resource_group.aks_group1.name
  dns_prefix          = "aks-dns"

  default_node_pool {
    name       = "akspool"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  # addon_profile {
  #   oms_agent {
  #     enabled                    = true
  #     log_analytics_workspace_id = azurerm_log_analytics_workspace.aks_log.id
  #   }
  # }

  tags = {
    Environment = "Production"
  }
}

resource "azurerm_monitor_action_group" "aks_monitor_rg" {
  name                = "aks-monitor-rg"
  resource_group_name = azurerm_resource_group.aks_group1.name
  short_name          = "aks-monitor"

  email_receiver {
    name          = "cpu-alert-email"
    email_address = "shaikmohammedidrees9920@gmail.com"
  }
}
resource "azurerm_log_analytics_workspace" "aks_log" {
  name                = "aks-log-analytics"
  location            = azurerm_resource_group.aks_group1.location
  resource_group_name = azurerm_resource_group.aks_group1.name
  sku                 = "PerGB2018"

  retention_in_days = 30
}


# resource "azurerm_monitor_metric_alert" "cpu_alert" {
#   name                = "high-cpu-alert"
#   resource_group_name = azurerm_resource_group.aks_group1.name
#   scopes              = [azurerm_kubernetes_cluster.aks_cluster.id]
#   description         = "Alert for high CPU usage on AKS cluster"
#   severity            = 3
#   frequency           = "PT1M"
#   window_size         = "PT5M"

#   criteria {
#     metric_namespace = "Microsoft.ContainerService/managedClusters"
#     metric_name      = "cpuUsagePercentage"
#     aggregation      = "Average"
#     operator         = "GreaterThan"
#     threshold        = 80
#   }

#   action {
#     action_group_id = azurerm_monitor_action_group.aks_monitor_rg.id
#   }
# }
resource "azurerm_monitor_scheduled_query_rules_alert" "cpu_alert" {
  name                = "high-cpu-alert"
  resource_group_name = azurerm_resource_group.aks_group1.name
  location            = azurerm_resource_group.aks_group1.location
  description         = "Alert for high CPU usage in AKS cluster"
  severity            = 3
  enabled             = true
  scopes              = [azurerm_log_analytics_workspace.aks_log.id]
  frequency           = "PT5M"      # Check every 5 minutes
  window_size         = "PT5M"      # Evaluate over the last 5 minutes

  criteria {
    query = <<-QUERY
      InsightsMetrics
      | where Namespace == "ContainerInsights" and Name == "cpuUsagePercentage"
      | summarize avgCpuUsage = avg(Val) by bin(TimeGenerated, 5m)
      | where avgCpuUsage > 80
    QUERY
    time_aggregation = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.aks_monitor_rg.id
  }
}
