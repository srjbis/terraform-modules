mock_provider "azurerm" {
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test/subnets/nodes" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aks-test-identity"
      principal_id = "11111111-1111-1111-1111-111111111111"
      client_id    = "11111111-1111-1111-1111-111111111111"
      tenant_id    = "11111111-1111-1111-1111-111111111111"
    }
  }
  mock_resource "azurerm_kubernetes_cluster" {
    defaults = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test" }
  }
}

variables {
  name                   = "aks-test"
  resource_group_name    = "rg-test"
  location               = "eastus2"
  dns_prefix             = "aks-test"
  admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]
}

run "all_original_defaults" {
  command = plan
  assert {
    condition = (
      !azurerm_kubernetes_cluster.this.private_cluster_public_fqdn_enabled &&
      azurerm_kubernetes_cluster.this.private_dns_zone_id == "System" &&
      azurerm_kubernetes_cluster.this.role_based_access_control_enabled &&
      azurerm_kubernetes_cluster.this.local_account_disabled &&
      azurerm_kubernetes_cluster.this.azure_policy_enabled &&
      azurerm_kubernetes_cluster.this.oidc_issuer_enabled &&
      azurerm_kubernetes_cluster.this.workload_identity_enabled &&
      !azurerm_kubernetes_cluster.this.run_command_enabled &&
      azurerm_kubernetes_cluster.this.node_os_upgrade_channel == "NodeImage" &&
      azurerm_kubernetes_cluster.this.identity[0].type == "UserAssigned" &&
      azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].temporary_name_for_rotation == "rotation" &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].auto_scaling_enabled &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].os_sku == "Ubuntu" &&
      !azurerm_kubernetes_cluster.this.default_node_pool[0].node_public_ip_enabled &&
      azurerm_kubernetes_cluster.this.network_profile[0].network_plugin == "azure" &&
      azurerm_kubernetes_cluster.this.network_profile[0].network_plugin_mode == "overlay" &&
      azurerm_kubernetes_cluster.this.network_profile[0].network_policy == "calico" &&
      azurerm_kubernetes_cluster.this.network_profile[0].load_balancer_sku == "standard" &&
      azurerm_kubernetes_cluster.this.network_profile[0].outbound_type == "loadBalancer" &&
      azurerm_kubernetes_cluster.this.network_profile[0].service_cidr == "10.1.0.0/16" &&
      azurerm_kubernetes_cluster.this.network_profile[0].dns_service_ip == "10.1.0.10" &&
      azurerm_kubernetes_cluster.this.network_profile[0].pod_cidr == "10.244.0.0/16"
    )
    error_message = "Omitted inputs must preserve every original AKS default."
  }
}

run "override_cluster_settings" {
  command = apply
  variables {
    private_cluster_public_fqdn_enabled = true
    private_dns_zone_id                 = "None"
    local_account_disabled              = false
    azure_policy_enabled                = false
    oidc_issuer_enabled                 = false
    workload_identity_enabled           = false
    run_command_enabled                 = true
    node_os_upgrade_channel             = "SecurityPatch"
    azure_rbac_enabled                  = false
    identity_type                       = "SystemAssigned"
    system_node_pool = {
      temporary_name_for_rotation = "rolling"
      os_sku                      = "AzureLinux"
      node_public_ip_enabled      = true
    }
    network_profile = {
      service_cidr   = "172.20.0.0/16"
      dns_service_ip = "172.20.0.53"
      pod_cidr       = "172.21.0.0/16"
    }
  }
  assert {
    condition = (
      azurerm_kubernetes_cluster.this.private_cluster_public_fqdn_enabled &&
      azurerm_kubernetes_cluster.this.private_dns_zone_id == "None" &&
      !azurerm_kubernetes_cluster.this.local_account_disabled &&
      !azurerm_kubernetes_cluster.this.azure_policy_enabled &&
      !azurerm_kubernetes_cluster.this.oidc_issuer_enabled &&
      !azurerm_kubernetes_cluster.this.workload_identity_enabled &&
      azurerm_kubernetes_cluster.this.run_command_enabled &&
      azurerm_kubernetes_cluster.this.node_os_upgrade_channel == "SecurityPatch" &&
      !azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled &&
      azurerm_kubernetes_cluster.this.identity[0].type == "SystemAssigned" &&
      length(azurerm_user_assigned_identity.this) == 0 &&
      length(azurerm_role_assignment.network) == 0 &&
      azurerm_role_assignment.system_network[0].principal_id == output.identity_principal_id &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].temporary_name_for_rotation == "rolling" &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].os_sku == "AzureLinux" &&
      azurerm_kubernetes_cluster.this.default_node_pool[0].node_public_ip_enabled &&
      azurerm_kubernetes_cluster.this.network_profile[0].service_cidr == "172.20.0.0/16" &&
      azurerm_kubernetes_cluster.this.network_profile[0].dns_service_ip == "172.20.0.53" &&
      azurerm_kubernetes_cluster.this.network_profile[0].pod_cidr == "172.21.0.0/16"
    )
    error_message = "Explicit settings must reach AKS and select the correct identity resources."
  }
}

run "fixed_size_pool" {
  command = apply
  variables {
    system_node_pool = { auto_scaling_enabled = false, node_count = 3 }
  }
  assert {
    condition     = !azurerm_kubernetes_cluster.this.default_node_pool[0].auto_scaling_enabled && azurerm_kubernetes_cluster.this.default_node_pool[0].node_count == 3
    error_message = "Disabling autoscaling must use the requested fixed node count."
  }
}

run "resize_fixed_pool" {
  command = plan
  variables {
    system_node_pool = { auto_scaling_enabled = false, node_count = 4 }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].node_count == 4
    error_message = "Lifecycle rules must not ignore changes to a fixed pool's node count."
  }
}

run "disable_rbac" {
  command = plan
  variables {
    role_based_access_control_enabled = false
    azure_rbac_enabled                = false
    local_account_disabled            = false
  }
  assert {
    condition     = !azurerm_kubernetes_cluster.this.role_based_access_control_enabled && length(azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control) == 0
    error_message = "Disabling Kubernetes RBAC must omit incompatible Entra integration."
  }
}

run "flat_azure_network" {
  command = plan
  variables {
    network_profile = { network_plugin_mode = "none", network_policy = "azure" }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_policy == "azure" && !local.uses_pod_cidr
    error_message = "Flat Azure CNI must configure Azure policy without an overlay pod CIDR."
  }
}

run "kubenet_network" {
  command = plan
  variables {
    network_profile = { network_plugin = "kubenet", network_plugin_mode = "none" }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_plugin == "kubenet" && local.uses_pod_cidr
    error_message = "Kubenet must retain its pod CIDR."
  }
}

run "cilium_network" {
  command = plan
  variables {
    network_profile = { network_policy = "cilium", network_data_plane = "cilium" }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_policy == "cilium" && azurerm_kubernetes_cluster.this.network_profile[0].network_data_plane == "cilium"
    error_message = "Cilium policy and data plane must be passed through together."
  }
}

run "nat_egress" {
  command = plan
  variables {
    network_profile = { outbound_type = "userAssignedNATGateway" }
  }
  assert {
    condition     = length(azurerm_nat_gateway.this) == 1 && length(azurerm_public_ip.nat) == 1 && length(azurerm_nat_gateway_public_ip_association.this) == 1 && length(azurerm_subnet_nat_gateway_association.this) == 1 && azurerm_kubernetes_cluster.this.network_profile[0].outbound_type == "userAssignedNATGateway"
    error_message = "NAT egress must create and attach all prerequisites."
  }
}

run "custom_dns_zone" {
  command = plan
  variables {
    private_dns_zone_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.eastus2.azmk8s.io"
  }
  assert {
    condition     = azurerm_role_assignment.private_dns[0].scope == var.private_dns_zone_id && azurerm_kubernetes_cluster.this.private_dns_zone_id == var.private_dns_zone_id
    error_message = "Custom DNS must receive a role assignment and reach AKS."
  }
}
