locals {
  existing_parts     = var.existing_aks == null ? [] : split("/", var.existing_aks.id == null ? "" : var.existing_aks.id)
  existing_subnet_id = var.existing_aks == null ? null : try(data.azurerm_kubernetes_cluster.existing[0].agent_pool_profile[0].vnet_subnet_id, null)
}

# Reading the cluster proves it exists. A missing or inaccessible supplied ID is
# an error, never a signal to silently create a different cluster.
data "azurerm_kubernetes_cluster" "existing" {
  count = var.existing_aks == null ? 0 : 1

  name                = try(local.existing_parts[8], "invalid")
  resource_group_name = try(local.existing_parts[4], "invalid")

  lifecycle {
    postcondition {
      condition     = lower(self.id) == lower(var.existing_aks.id)
      error_message = "The cluster returned by Azure does not match existing_aks.id. Configure the provider for the ID's subscription."
    }
  }
}

module "aks" {
  source   = "../aks"
  for_each = var.aks == null ? {} : { this = var.aks }

  name                   = each.value.name
  resource_group_name    = each.value.resource_group_name
  location               = each.value.location
  dns_prefix             = each.value.dns_prefix
  admin_group_object_ids = each.value.admin_group_object_ids
  kubernetes_version     = each.value.kubernetes_version
  sku_tier               = each.value.sku_tier
  api_access             = each.value.api_access
  system_node_pool       = each.value.system_node_pool
  network                = each.value.network
  tags                   = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "this" {
  name                        = var.name
  temporary_name_for_rotation = "${var.name}r"
  kubernetes_cluster_id       = var.existing_aks != null ? data.azurerm_kubernetes_cluster.existing[0].id : try(module.aks["this"].id, null)
  vnet_subnet_id              = var.existing_aks != null ? (local.existing_subnet_id == "" ? null : local.existing_subnet_id) : try(module.aks["this"].subnet_id, null)
  vm_size                     = var.vm_size
  mode                        = "User"
  os_type                     = "Linux"
  os_sku                      = "Ubuntu"
  auto_scaling_enabled        = true
  min_count                   = var.scaling.min_count
  max_count                   = var.scaling.max_count
  zones                       = var.zones
  node_public_ip_enabled      = false
  tags                        = var.tags

  lifecycle {
    ignore_changes = [node_count]
    precondition {
      condition     = var.existing_aks == null ? true : length(data.azurerm_kubernetes_cluster.existing[0].agent_pool_profile) > 0 && alltrue([for pool in data.azurerm_kubernetes_cluster.existing[0].agent_pool_profile : pool.type == "VirtualMachineScaleSets"])
      error_message = "The existing AKS cluster must use VirtualMachineScaleSets to support additional node pools."
    }
  }
}
