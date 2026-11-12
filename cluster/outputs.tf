# Diese fünf Werte kommen als Variablen ins GitHub-Repo
# (Settings → Secrets and variables → Actions → Variables).
output "github_variablen" {
  description = "Variablen für die Pipeline: Name = Wert."
  value = {
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.deploy.client_id
    AZURE_TENANT_ID       = azurerm_user_assigned_identity.deploy.tenant_id
    AZURE_SUBSCRIPTION_ID = var.subscription_id
    AKS_RESSOURCENGRUPPE  = azurerm_resource_group.cluster.name
    AKS_CLUSTER           = azurerm_kubernetes_cluster.cluster.name
  }
}

output "kubectl_kontext" {
  description = "Trägt das Cluster als kubectl-Kontext ein, zum Nachsehen."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.cluster.name} --name ${azurerm_kubernetes_cluster.cluster.name} --context ${var.name}"
}
