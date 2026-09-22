resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  private_cluster_enabled             = var.api_access.private_cluster_enabled
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = var.api_access.private_cluster_enabled ? "System" : null
  role_based_access_control_enabled   = true
  local_account_disabled              = true
  azure_policy_enabled                = true
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  run_command_enabled                 = false
  node_os_upgrade_channel             = "NodeImage"

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  dynamic "api_server_access_profile" {
    for_each = var.api_access.private_cluster_enabled ? [] : [var.api_access.authorized_ip_ranges]
    content {
      authorized_ip_ranges = api_server_access_profile.value
    }
  }

  default_node_pool {
    name                        = var.system_node_pool.name
    temporary_name_for_rotation = "rotation"
    vm_size                     = var.system_node_pool.vm_size
    auto_scaling_enabled        = true
    min_count                   = var.system_node_pool.min_count
    max_count                   = var.system_node_pool.max_count
    zones                       = var.system_node_pool.zones
    os_sku                      = "Ubuntu"
    node_public_ip_enabled      = false
    tags                        = var.tags
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }
}
