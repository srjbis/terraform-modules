resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  private_cluster_enabled             = var.api_access.private_cluster_enabled
  private_cluster_public_fqdn_enabled = var.private_cluster_public_fqdn_enabled
  private_dns_zone_id                 = var.api_access.private_cluster_enabled ? var.private_dns_zone_id : null
  role_based_access_control_enabled   = var.role_based_access_control_enabled
  local_account_disabled              = var.local_account_disabled
  azure_policy_enabled                = var.azure_policy_enabled
  oidc_issuer_enabled                 = var.oidc_issuer_enabled
  workload_identity_enabled           = var.workload_identity_enabled
  run_command_enabled                 = var.run_command_enabled
  node_os_upgrade_channel             = var.node_os_upgrade_channel

  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "UserAssigned" ? [azurerm_user_assigned_identity.this[0].id] : null
  }

  dynamic "azure_active_directory_role_based_access_control" {
    for_each = var.role_based_access_control_enabled ? [var.azure_rbac_enabled] : []
    content {
      azure_rbac_enabled     = azure_active_directory_role_based_access_control.value
      admin_group_object_ids = var.admin_group_object_ids
    }
  }

  dynamic "api_server_access_profile" {
    for_each = var.api_access.private_cluster_enabled ? [] : [var.api_access.authorized_ip_ranges]
    content {
      authorized_ip_ranges = api_server_access_profile.value
    }
  }

  default_node_pool {
    vnet_subnet_id              = module.network.subnet_id
    name                        = var.system_node_pool.name
    temporary_name_for_rotation = var.system_node_pool.temporary_name_for_rotation
    vm_size                     = var.system_node_pool.vm_size
    auto_scaling_enabled        = var.system_node_pool.auto_scaling_enabled
    min_count                   = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.min_count : null
    max_count                   = var.system_node_pool.auto_scaling_enabled ? var.system_node_pool.max_count : null
    node_count                  = var.system_node_pool.auto_scaling_enabled ? null : var.system_node_pool.node_count
    zones                       = var.system_node_pool.zones
    os_sku                      = var.system_node_pool.os_sku
    node_public_ip_enabled      = var.system_node_pool.node_public_ip_enabled
    tags                        = var.tags
  }

  network_profile {
    network_plugin      = var.network_profile.network_plugin
    network_plugin_mode = var.network_profile.network_plugin_mode == "none" ? null : var.network_profile.network_plugin_mode
    network_policy      = var.network_profile.network_policy == "none" ? null : var.network_profile.network_policy
    network_data_plane  = var.network_profile.network_data_plane
    load_balancer_sku   = var.network_profile.load_balancer_sku
    outbound_type       = var.network_profile.outbound_type
    service_cidr        = var.network_profile.service_cidr
    dns_service_ip      = var.network_profile.dns_service_ip
    pod_cidr            = local.uses_pod_cidr ? var.network_profile.pod_cidr : null
  }

  tags = var.tags

  depends_on = [azurerm_role_assignment.network, azurerm_role_assignment.private_dns, azurerm_subnet_nat_gateway_association.this]
}
