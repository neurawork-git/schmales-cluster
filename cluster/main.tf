# Das Cluster als Datei.
# Anlegen:  tofu init; tofu apply
# Abbauen:  tofu destroy
# Alles liegt in einer eigenen Ressourcengruppe, damit der Abbau nichts anderes berührt.

terraform {
  required_version = ">= 1.8"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

resource "azurerm_resource_group" "cluster" {
  name     = "rg-${var.name}"
  location = var.region
}

# Das Cluster: Steuerungsebene im kostenlosen Tarif, ein Pool mit zwei Rechnern.
resource "azurerm_kubernetes_cluster" "cluster" {
  name                = "aks-${var.name}"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
  dns_prefix          = var.name
  sku_tier            = "Free"

  # Damit sich GitHub Actions ohne gespeichertes Passwort anmelden kann.
  oidc_issuer_enabled = true

  default_node_pool {
    name       = "system"
    vm_size    = var.node_size
    node_count = var.node_count
  }

  identity {
    type = "SystemAssigned"
  }
}

# Identität für die Pipeline: GitHub Actions weist sich per OIDC aus,
# es gibt kein Passwort, das ablaufen oder durchsickern kann.
resource "azurerm_user_assigned_identity" "deploy" {
  name                = "id-${var.name}-deploy"
  location            = azurerm_resource_group.cluster.location
  resource_group_name = azurerm_resource_group.cluster.name
}

# Verbundanmeldung: nur Läufe auf dem Branch main dieses einen Repos.
resource "azurerm_federated_identity_credential" "github_main" {
  name      = "github-main"
  parent_id = azurerm_user_assigned_identity.deploy.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = "https://token.actions.githubusercontent.com"
  subject   = "repo:${var.github_repo}:ref:refs/heads/main"
}

# Die Pipeline darf genau dieses Cluster ansprechen, sonst nichts im Abo.
resource "azurerm_role_assignment" "deploy_cluster_user" {
  scope                = azurerm_kubernetes_cluster.cluster.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
}
