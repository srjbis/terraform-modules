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
  mock_data "azurerm_kubernetes_cluster" {
    defaults = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
      agent_pool_profile = [{
        name           = "system"
        type           = "VirtualMachineScaleSets"
        vnet_subnet_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test/subnets/nodes"
      }]
    }
  }
}

variables {
  name         = "apps"
  existing_aks = { id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test" }
}

run "attach_existing_cluster" {
  command = apply
  assert {
    condition     = length(module.aks) == 0 && length(data.azurerm_kubernetes_cluster.existing) == 1 && !output.created_aks && output.network_id == null
    error_message = "Existing mode must only read the cluster, without creating AKS or networking."
  }
  assert {
    condition     = output.aks_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test" && output.subnet_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test/subnets/nodes" && azurerm_kubernetes_cluster_node_pool.this.mode == "User" && !azurerm_kubernetes_cluster_node_pool.this.node_public_ip_enabled && azurerm_kubernetes_cluster_node_pool.this.temporary_name_for_rotation == "appsr"
    error_message = "The additional pool must attach to the existing cluster and subnet."
  }
}

run "create_full_chain" {
  command = apply
  variables {
    existing_aks = null
    aks = {
      name                   = "aks-test"
      resource_group_name    = "rg-test"
      location               = "eastus2"
      dns_prefix             = "aks-test"
      admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]
    }
    scaling = { min_count = 0, max_count = 10 }
    zones   = ["1", "2"]
    vm_size = "Standard_D8s_v5"
    tags    = { environment = "test" }
  }
  assert {
    condition     = length(module.aks) == 1 && length(data.azurerm_kubernetes_cluster.existing) == 0 && output.created_aks && output.aks_id == module.aks["this"].id && output.subnet_id == module.aks["this"].subnet_id && output.network_id == module.aks["this"].network_id
    error_message = "New mode must create network, AKS and then attach the user pool."
  }
  assert {
    condition     = azurerm_kubernetes_cluster_node_pool.this.min_count == 0 && azurerm_kubernetes_cluster_node_pool.this.max_count == 10 && azurerm_kubernetes_cluster_node_pool.this.vm_size == "Standard_D8s_v5" && toset(azurerm_kubernetes_cluster_node_pool.this.zones) == toset(["1", "2"]) && azurerm_kubernetes_cluster_node_pool.this.tags["environment"] == "test"
    error_message = "Pool scaling, zones, VM size and tags must be preserved."
  }
}

run "valid_maximum" {
  command = plan
  variables {
    name    = "abcdefghijk"
    scaling = { min_count = 1000, max_count = 1000 }
  }
}

run "create_with_configurable_aks" {
  command = apply
  variables {
    existing_aks = null
    aks = {
      name                                = "aks-test"
      resource_group_name                 = "rg-test"
      location                            = "eastus2"
      dns_prefix                          = "aks-test"
      admin_group_object_ids              = ["11111111-1111-1111-1111-111111111111"]
      identity_type                       = "SystemAssigned"
      private_cluster_public_fqdn_enabled = true
      private_dns_zone_id                 = "None"
      role_based_access_control_enabled   = false
      azure_rbac_enabled                  = false
      local_account_disabled              = false
      azure_policy_enabled                = false
      oidc_issuer_enabled                 = false
      workload_identity_enabled           = false
      run_command_enabled                 = true
      node_os_upgrade_channel             = "SecurityPatch"
      system_node_pool = {
        auto_scaling_enabled        = false
        node_count                  = 3
        os_sku                      = "AzureLinux"
        node_public_ip_enabled      = true
        temporary_name_for_rotation = "rolling"
      }
      # This VNet overlaps the OLD service range: custom service_cidr must
      # reach the child module for the configuration to pass validation.
      network = { address_space = "10.1.0.0/16", subnet_prefix = "10.1.0.0/22" }
      network_profile = {
        service_cidr   = "172.21.0.0/16"
        dns_service_ip = "172.21.0.53"
        pod_cidr       = "172.22.0.0/16"
      }
    }
  }
  assert {
    condition     = output.created_aks && output.aks_id == module.aks["this"].id
    error_message = "AKS configuration overrides must work through the node-pool entry point."
  }
}

run "existing_azure_managed_subnet" {
  command = plan
  override_data {
    target = data.azurerm_kubernetes_cluster.existing[0]
    values = {
      id                 = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
      agent_pool_profile = [{ name = "system", type = "VirtualMachineScaleSets", vnet_subnet_id = "" }]
    }
  }
  assert {
    condition     = length(module.aks) == 0 && azurerm_kubernetes_cluster_node_pool.this.kubernetes_cluster_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
    error_message = "An empty subnet in the Azure response must allow Azure-managed subnet selection."
  }
}

run "existing_pool_visible_on_refresh" {
  command = plan
  override_data {
    target = data.azurerm_kubernetes_cluster.existing[0]
    values = {
      id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
      agent_pool_profile = [
        { name = "system", type = "VirtualMachineScaleSets", vnet_subnet_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test/subnets/nodes" },
        { name = "apps", type = "VirtualMachineScaleSets", vnet_subnet_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test/subnets/nodes" }
      ]
    }
  }
  assert {
    condition     = length(module.aks) == 0 && azurerm_kubernetes_cluster_node_pool.this.kubernetes_cluster_id == "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
    error_message = "Reading our own pool on later refreshes must not trigger cluster creation or fail validation."
  }
}

run "wrong_subscription" {
  command = plan
  override_data {
    target = data.azurerm_kubernetes_cluster.existing[0]
    values = {
      id                 = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
      agent_pool_profile = [{ name = "system", type = "VirtualMachineScaleSets", vnet_subnet_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test/subnets/nodes" }]
    }
  }
  expect_failures = [data.azurerm_kubernetes_cluster.existing[0]]
}

run "incompatible_existing_cluster" {
  command = plan
  override_data {
    target = data.azurerm_kubernetes_cluster.existing[0]
    values = {
      id                 = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.ContainerService/managedClusters/aks-test"
      agent_pool_profile = [{ name = "system", type = "AvailabilitySet", vnet_subnet_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/aks-test/subnets/nodes" }]
    }
  }
  expect_failures = [azurerm_kubernetes_cluster_node_pool.this]
}
