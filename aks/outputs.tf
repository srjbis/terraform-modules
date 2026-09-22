output "id" {
  description = "AKS resource ID, usable as a scope for additional Azure role assignments."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "Cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "node_resource_group" {
  description = "Azure-managed resource group containing cluster nodes and networking."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}

output "oidc_issuer_url" {
  description = "Issuer URL for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "identity_principal_id" {
  description = "Principal ID of the cluster's system-assigned managed identity."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "kubelet_identity" {
  description = "Kubelet identity, for example for caller-managed AcrPull role assignments."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity
}
