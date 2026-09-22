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

run "network_and_identity_wiring" {
  command = apply
  variables {
    network = { address_space = "172.20.0.0/16", subnet_prefix = "172.20.0.0/22" }
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.default_node_pool[0].vnet_subnet_id == module.network.subnet_id && output.network_id == module.network.id && output.subnet_id == module.network.subnet_id
    error_message = "AKS must attach to the subnet created by the network module."
  }
  assert {
    condition     = azurerm_kubernetes_cluster.this.identity[0].type == "UserAssigned" && azurerm_kubernetes_cluster.this.identity[0].identity_ids == toset([azurerm_user_assigned_identity.this.id]) && azurerm_role_assignment.network.scope == module.network.id && azurerm_role_assignment.network.principal_id == azurerm_user_assigned_identity.this.principal_id && azurerm_role_assignment.network.role_definition_name == "Network Contributor"
    error_message = "Cluster identity must receive network authorization."
  }
}

run "reject_service_overlap" {
  command = plan
  variables {
    network = { address_space = "10.1.0.0/16", subnet_prefix = "10.1.0.0/22" }
  }
  expect_failures = [var.network]
}

run "reject_pod_overlap" {
  command = plan
  variables {
    network = { address_space = "10.244.0.0/16", subnet_prefix = "10.244.0.0/22" }
  }
  expect_failures = [var.network]
}

run "reject_supernet_overlap" {
  command = plan
  variables {
    network = { address_space = "10.0.0.0/8" }
  }
  expect_failures = [var.network]
}
