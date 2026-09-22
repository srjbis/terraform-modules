output "id" {
  description = "Virtual network resource ID."
  value       = azurerm_virtual_network.this.id
}

output "name" {
  description = "Virtual network name."
  value       = azurerm_virtual_network.this.name
}

output "subnet_id" {
  description = "Workload subnet resource ID."
  value       = azurerm_subnet.this.id
}

output "address_space" {
  description = "Virtual network IPv4 CIDR."
  value       = var.address_space
}

output "subnet_prefix" {
  description = "Workload subnet IPv4 CIDR."
  value       = var.subnet_prefix
}
