output "id" {
  description = "Additional node pool resource ID."
  value       = azurerm_kubernetes_cluster_node_pool.this.id
}

output "name" {
  description = "Additional node pool name."
  value       = azurerm_kubernetes_cluster_node_pool.this.name
}

output "aks_id" {
  description = "Existing or newly created AKS resource ID."
  value       = azurerm_kubernetes_cluster_node_pool.this.kubernetes_cluster_id
}

output "created_aks" {
  description = "Whether this module owns a newly created cluster and network."
  value       = var.existing_aks == null
}

output "subnet_id" {
  description = "Subnet used by the additional pool."
  value       = azurerm_kubernetes_cluster_node_pool.this.vnet_subnet_id
}

output "network_id" {
  description = "New virtual network ID, or null when using an existing cluster."
  value       = try(module.aks["this"].network_id, null)
}
