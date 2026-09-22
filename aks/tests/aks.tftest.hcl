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

run "secure_defaults" {
  command = plan
  assert {
    condition = (
      azurerm_kubernetes_cluster.this.private_cluster_enabled &&
      !azurerm_kubernetes_cluster.this.private_cluster_public_fqdn_enabled &&
      azurerm_kubernetes_cluster.this.local_account_disabled &&
      azurerm_kubernetes_cluster.this.role_based_access_control_enabled &&
      azurerm_kubernetes_cluster.this.azure_active_directory_role_based_access_control[0].azure_rbac_enabled &&
      azurerm_kubernetes_cluster.this.azure_policy_enabled &&
      !azurerm_kubernetes_cluster.this.run_command_enabled &&
      azurerm_kubernetes_cluster.this.oidc_issuer_enabled &&
      azurerm_kubernetes_cluster.this.workload_identity_enabled &&
      !azurerm_kubernetes_cluster.this.default_node_pool[0].node_public_ip_enabled
    )
    error_message = "Security defaults must remain enabled."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].auto_scaling_enabled && azurerm_kubernetes_cluster.this.default_node_pool[0].min_count == 2 && azurerm_kubernetes_cluster.this.default_node_pool[0].max_count == 5
    error_message = "Default system pool must autoscale from two to five nodes."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.network_profile[0].network_plugin_mode == "overlay" && azurerm_kubernetes_cluster.this.network_profile[0].network_policy == "calico"
    error_message = "Azure CNI overlay with network policy must be configured."
  }
}

run "public_allowlist_and_custom_pool" {
  command = plan
  variables {
    api_access = {
      private_cluster_enabled = false
      authorized_ip_ranges    = ["203.0.113.8/32"]
    }
    system_node_pool = {
      name      = "sys01"
      vm_size   = "Standard_D8s_v5"
      min_count = 3
      max_count = 10
      zones     = ["1", "2", "3"]
    }
    sku_tier = "Free"
    tags     = { environment = "test" }
  }
  assert {
    condition     = !azurerm_kubernetes_cluster.this.private_cluster_enabled && azurerm_kubernetes_cluster.this.api_server_access_profile[0].authorized_ip_ranges == toset(["203.0.113.8/32"])
    error_message = "Public access must preserve the explicit allowlist."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].vm_size == "Standard_D8s_v5" && azurerm_kubernetes_cluster.this.default_node_pool[0].min_count == 3 && azurerm_kubernetes_cluster.this.default_node_pool[0].max_count == 10 && toset(azurerm_kubernetes_cluster.this.default_node_pool[0].zones) == toset(["1", "2", "3"]) && azurerm_kubernetes_cluster.this.tags["environment"] == "test" && azurerm_kubernetes_cluster.this.default_node_pool[0].tags["environment"] == "test" && azurerm_kubernetes_cluster.this.sku_tier == "Free"
    error_message = "Custom pool, tags and SKU must reach the resource."
  }
}

run "mock_apply_outputs" {
  command = apply
  assert {
    condition     = output.name == "aks-test" && output.id == azurerm_kubernetes_cluster.this.id && output.oidc_issuer_url == azurerm_kubernetes_cluster.this.oidc_issuer_url && output.identity_principal_id == azurerm_user_assigned_identity.this.principal_id && output.node_resource_group == azurerm_kubernetes_cluster.this.node_resource_group && output.kubelet_identity == azurerm_kubernetes_cluster.this.kubelet_identity
    error_message = "Outputs must expose the corresponding cluster attributes."
  }
}

run "valid_lower_boundaries" {
  command = plan
  variables {
    name               = "a"
    dns_prefix         = "a"
    kubernetes_version = "1.34"
    system_node_pool   = { name = "a", min_count = 1, max_count = 1 }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.name == "a" && azurerm_kubernetes_cluster.this.kubernetes_version == "1.34" && azurerm_kubernetes_cluster.this.default_node_pool[0].min_count == 1
    error_message = "Valid lower boundaries and minor version aliases must be accepted."
  }
}

run "valid_upper_boundaries" {
  command = plan
  variables {
    name               = join("", [for i in range(63) : "a"])
    dns_prefix         = join("", [for i in range(54) : "a"])
    kubernetes_version = "1.34.1"
    system_node_pool   = { name = "abcdefghijkl", min_count = 1000, max_count = 1000 }
    tags               = { for i in range(50) : "key${i}" => join("", [for j in range(256) : "v"]) }
  }
  assert {
    condition     = length(azurerm_kubernetes_cluster.this.name) == 63 && azurerm_kubernetes_cluster.this.default_node_pool[0].max_count == 1000 && length(azurerm_kubernetes_cluster.this.tags) == 50
    error_message = "Valid upper boundaries must be accepted by the module."
  }
}
