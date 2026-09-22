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

run "public_fqdn_on_public" {
  command = plan
  variables {
    private_cluster_public_fqdn_enabled = true
    api_access                          = { private_cluster_enabled = false, authorized_ip_ranges = ["203.0.113.1/32"] }
  }
  expect_failures = [var.private_cluster_public_fqdn_enabled]
}

run "invalid_dns_zone" {
  command = plan
  variables {
    private_dns_zone_id = "bad-zone"
  }
  expect_failures = [var.private_dns_zone_id]
}

run "custom_dns_with_system_identity" {
  command = plan
  variables {
    identity_type       = "SystemAssigned"
    private_dns_zone_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-dns/providers/Microsoft.Network/privateDnsZones/privatelink.eastus2.azmk8s.io"
  }
  expect_failures = [var.private_dns_zone_id]
}

run "dns_none_without_fqdn" {
  command = plan
  variables {
    private_dns_zone_id = "None"
  }
  expect_failures = [var.private_dns_zone_id]
}

run "workload_without_oidc" {
  command = plan
  variables {
    oidc_issuer_enabled = false
  }
  expect_failures = [var.workload_identity_enabled]
}

run "local_disabled_without_rbac" {
  command = plan
  variables {
    role_based_access_control_enabled = false
    azure_rbac_enabled                = false
  }
  expect_failures = [var.local_account_disabled]
}

run "azure_rbac_without_rbac" {
  command = plan
  variables {
    role_based_access_control_enabled = false
    local_account_disabled            = false
  }
  expect_failures = [var.azure_rbac_enabled]
}

run "invalid_identity" {
  command = plan
  variables {
    identity_type = "ServicePrincipal"
  }
  expect_failures = [var.identity_type]
}

run "invalid_os_channel" {
  command = plan
  variables {
    node_os_upgrade_channel = "daily"
  }
  expect_failures = [var.node_os_upgrade_channel]
}

run "invalid_rotation" {
  command = plan
  variables {
    system_node_pool = { temporary_name_for_rotation = "Bad-Name" }
  }
  expect_failures = [var.system_node_pool]
}

run "rotation_collision" {
  command = plan
  variables {
    system_node_pool = { temporary_name_for_rotation = "system" }
  }
  expect_failures = [var.system_node_pool]
}

run "invalid_os_sku" {
  command = plan
  variables {
    system_node_pool = { os_sku = "Windows2022" }
  }
  expect_failures = [var.system_node_pool]
}

run "zero_fixed_count" {
  command = plan
  variables {
    system_node_pool = { auto_scaling_enabled = false, node_count = 0 }
  }
  expect_failures = [var.system_node_pool]
}

run "fractional_fixed_count" {
  command = plan
  variables {
    system_node_pool = { auto_scaling_enabled = false, node_count = 1.5 }
  }
  expect_failures = [var.system_node_pool]
}

run "excessive_fixed_count" {
  command = plan
  variables {
    system_node_pool = { auto_scaling_enabled = false, node_count = 1001 }
  }
  expect_failures = [var.system_node_pool]
}

run "plugin" {
  command = plan
  variables {
    network_profile = { network_plugin = "invalid" }
  }
  expect_failures = [var.network_profile]
}

run "plugin_mode" {
  command = plan
  variables {
    network_profile = { network_plugin_mode = "bridge" }
  }
  expect_failures = [var.network_profile]
}

run "overlay_with_kubenet" {
  command = plan
  variables {
    network_profile = { network_plugin = "kubenet" }
  }
  expect_failures = [var.network_profile]
}

run "policy" {
  command = plan
  variables {
    network_profile = { network_policy = "invalid" }
  }
  expect_failures = [var.network_profile]
}

run "azure_policy_overlay" {
  command = plan
  variables {
    network_profile = { network_policy = "azure" }
  }
  expect_failures = [var.network_profile]
}

run "data_plane" {
  command = plan
  variables {
    network_profile = { network_data_plane = "invalid" }
  }
  expect_failures = [var.network_profile]
}

run "cilium_without_plane" {
  command = plan
  variables {
    network_profile = { network_policy = "cilium" }
  }
  expect_failures = [var.network_profile]
}

run "cilium_with_calico" {
  command = plan
  variables {
    network_profile = { network_data_plane = "cilium" }
  }
  expect_failures = [var.network_profile]
}

run "basic_lb" {
  command = plan
  variables {
    network_profile = { load_balancer_sku = "basic" }
  }
  expect_failures = [var.network_profile]
}

run "invalid_egress" {
  command = plan
  variables {
    network_profile = { outbound_type = "invalid" }
  }
  expect_failures = [var.network_profile]
}

run "managed_nat_byovnet" {
  command = plan
  variables {
    network_profile = { outbound_type = "managedNATGateway" }
  }
  expect_failures = [var.network_profile]
}

run "unmanaged_routing" {
  command = plan
  variables {
    network_profile = { outbound_type = "userDefinedRouting" }
  }
  expect_failures = [var.network_profile]
}

run "bad_service" {
  command = plan
  variables {
    network_profile = { service_cidr = "not-cidr" }
  }
  expect_failures = [var.network_profile]
}

run "noncanonical_service" {
  command = plan
  variables {
    network_profile = { service_cidr = "10.1.0.1/16" }
  }
  expect_failures = [var.network_profile]
}

run "large_service" {
  command = plan
  variables {
    network_profile = { service_cidr = "10.16.0.0/12", dns_service_ip = "10.16.0.10" }
  }
  expect_failures = [var.network_profile]
}

run "ipv6_service" {
  command = plan
  variables {
    network_profile = { service_cidr = "2001:db8::/64" }
  }
  expect_failures = [var.network_profile]
}

run "bad_pods" {
  command = plan
  variables {
    network_profile = { pod_cidr = "not-cidr" }
  }
  expect_failures = [var.network_profile]
}

run "noncanonical_pods" {
  command = plan
  variables {
    network_profile = { pod_cidr = "10.244.0.1/16" }
  }
  expect_failures = [var.network_profile]
}

run "overlap_service_pods" {
  command = plan
  variables {
    network_profile = { pod_cidr = "10.1.0.0/16" }
  }
  expect_failures = [var.network_profile]
}

run "invalid_dns_ip" {
  command = plan
  variables {
    network_profile = { dns_service_ip = "999.1.1.1" }
  }
  expect_failures = [var.network_profile]
}

run "dns_outside_service" {
  command = plan
  variables {
    network_profile = { dns_service_ip = "10.2.0.10" }
  }
  expect_failures = [var.network_profile]
}

run "dns_reserved_first" {
  command = plan
  variables {
    network_profile = { dns_service_ip = "10.1.0.1" }
  }
  expect_failures = [var.network_profile]
}

run "dns_network_address" {
  command = plan
  variables {
    network_profile = { dns_service_ip = "10.1.0.0" }
  }
  expect_failures = [var.network_profile]
}

run "dns_broadcast" {
  command = plan
  variables {
    network_profile = { dns_service_ip = "10.1.255.255" }
  }
  expect_failures = [var.network_profile]
}

run "custom_service_vnet_overlap" {
  command = plan
  variables {
    network_profile = { service_cidr = "10.0.0.0/16", dns_service_ip = "10.0.0.10" }
  }
  expect_failures = [var.network]
}

run "custom_pod_vnet_overlap" {
  command = plan
  variables {
    network_profile = { pod_cidr = "10.0.0.0/16" }
  }
  expect_failures = [var.network]
}
