output "id" {
  description = "AKS resource ID, usable as a scope for additional Azure role assignments."
  value       = azurerm_kubernetes_cluster.this.id
  depends_on  = [azurerm_role_assignment.system_network]
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
  description = "Principal ID of the selected cluster managed identity."
  value       = var.identity_type == "UserAssigned" ? azurerm_user_assigned_identity.this[0].principal_id : azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "subnet_id" {
  description = "Subnet created by the network module and used by the system pool."
  value       = module.network.subnet_id
}

output "network_id" {
  description = "Virtual network created for this cluster."
  value       = module.network.id
}

output "kubelet_identity" {
  description = "Kubelet identity, for example for caller-managed AcrPull role assignments."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity
}
