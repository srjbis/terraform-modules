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

run "missing_cluster_config" {
  command = plan
  variables {
    existing_aks = null
  }
  expect_failures = [var.aks]
}

run "ambiguous_config" {
  command = plan
  variables {
    aks = {
      name                   = "aks-test"
      resource_group_name    = "rg-test"
      location               = "eastus2"
      dns_prefix             = "aks-test"
      admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]
    }
  }
  expect_failures = [var.aks]
}

run "invalid_cluster_id" {
  command = plan
  variables {
    existing_aks = { id = "bad-id" }
  }
  expect_failures = [var.existing_aks]
}

run "null_cluster_id" {
  command = plan
  variables {
    existing_aks = { id = null }
  }
  expect_failures = [var.existing_aks]
}

run "bad_name" {
  command = plan
  variables {
    name = "Bad-Pool"
  }
  expect_failures = [var.name]
}

run "long_name" {
  command = plan
  variables {
    name = "abcdefghijkl"
  }
  expect_failures = [var.name]
}

run "reserved_name" {
  command = plan
  variables {
    name = "rotation"
  }
  expect_failures = [var.name]
}

run "system_name_collision" {
  command = plan
  variables {
    existing_aks = null
    name         = "system"
    aks = {
      name                   = "aks-test"
      resource_group_name    = "rg-test"
      location               = "eastus2"
      dns_prefix             = "aks-test"
      admin_group_object_ids = ["11111111-1111-1111-1111-111111111111"]
    }
  }
  expect_failures = [var.name]
}

run "bad_sku" {
  command = plan
  variables {
    vm_size = "invalid"
  }
  expect_failures = [var.vm_size]
}

run "negative_min" {
  command = plan
  variables {
    scaling = { min_count = -1 }
  }
  expect_failures = [var.scaling]
}

run "inverted_scaling" {
  command = plan
  variables {
    scaling = { min_count = 6, max_count = 5 }
  }
  expect_failures = [var.scaling]
}

run "zero_max" {
  command = plan
  variables {
    scaling = { min_count = 0, max_count = 0 }
  }
  expect_failures = [var.scaling]
}

run "fractional_min" {
  command = plan
  variables {
    scaling = { min_count = 1.5 }
  }
  expect_failures = [var.scaling]
}

run "fractional_max" {
  command = plan
  variables {
    scaling = { max_count = 5.5 }
  }
  expect_failures = [var.scaling]
}

run "too_many_nodes" {
  command = plan
  variables {
    scaling = { max_count = 1001 }
  }
  expect_failures = [var.scaling]
}

run "invalid_zone" {
  command = plan
  variables {
    zones = ["4"]
  }
  expect_failures = [var.zones]
}

run "null_zone" {
  command = plan
  variables {
    zones = [null]
  }
  expect_failures = [var.zones]
}

run "bad_tag" {
  command = plan
  variables {
    tags = { "bad/key" = "value" }
  }
  expect_failures = [var.tags]
}

run "null_tag" {
  command = plan
  variables {
    tags = { environment = null }
  }
  expect_failures = [var.tags]
}
