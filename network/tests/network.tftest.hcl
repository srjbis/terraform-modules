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
  name                = "vnet-test"
  resource_group_name = "rg-test"
  location            = "eastus2"
}

run "standalone_network" {
  command = apply
  assert {
    condition     = toset(azurerm_virtual_network.this.address_space) == toset(["10.0.0.0/16"]) && azurerm_subnet.this.address_prefixes == tolist(["10.0.0.0/22"]) && azurerm_subnet.this.virtual_network_name == azurerm_virtual_network.this.name
    error_message = "The standalone subnet must belong to the configured VNet."
  }
  assert {
    condition     = output.id == azurerm_virtual_network.this.id && output.subnet_id == azurerm_subnet.this.id
    error_message = "Network outputs must reference created resources."
  }
}

run "custom_cidrs_and_tags" {
  command = plan
  variables {
    address_space = "172.20.0.0/16"
    subnet_prefix = "172.20.8.0/24"
    subnet_name   = "workers"
    tags          = { environment = "test" }
  }
  assert {
    condition     = azurerm_subnet.this.address_prefixes == tolist(["172.20.8.0/24"]) && azurerm_subnet.this.name == "workers" && azurerm_virtual_network.this.tags["environment"] == "test"
    error_message = "Custom subnet and tags must reach the resources."
  }
}

run "smallest_subnet" {
  command = plan
  variables {
    address_space = "192.168.0.0/29"
    subnet_prefix = "192.168.0.0/29"
  }
}

run "bad_name" {
  command = plan
  variables {
    name = "-bad"
  }
  expect_failures = [var.name]
}

run "bad_group" {
  command = plan
  variables {
    resource_group_name = "bad."
  }
  expect_failures = [var.resource_group_name]
}

run "bad_location" {
  command = plan
  variables {
    location = "East US"
  }
  expect_failures = [var.location]
}

run "bad_vnet" {
  command = plan
  variables {
    address_space = "garbage"
  }
  expect_failures = [var.address_space]
}

run "ipv6" {
  command = plan
  variables {
    address_space = "2001:db8::/32"
  }
  expect_failures = [var.address_space]
}

run "noncanonical_vnet" {
  command = plan
  variables {
    address_space = "10.0.0.1/16"
  }
  expect_failures = [var.address_space]
}

run "vnet_too_broad" {
  command = plan
  variables {
    address_space = "10.0.0.0/7"
  }
  expect_failures = [var.address_space]
}

run "bad_subnet" {
  command = plan
  variables {
    subnet_prefix = "not-cidr"
  }
  expect_failures = [var.subnet_prefix]
}

run "subnet_outside_vnet" {
  command = plan
  variables {
    subnet_prefix = "10.2.0.0/24"
  }
  expect_failures = [var.subnet_prefix]
}

run "subnet_larger_than_vnet" {
  command = plan
  variables {
    subnet_prefix = "10.0.0.0/8"
  }
  expect_failures = [var.subnet_prefix]
}

run "subnet_too_small" {
  command = plan
  variables {
    subnet_prefix = "10.0.0.0/30"
  }
  expect_failures = [var.subnet_prefix]
}

run "noncanonical_subnet" {
  command = plan
  variables {
    subnet_prefix = "10.0.0.1/24"
  }
  expect_failures = [var.subnet_prefix]
}

run "reserved_subnet" {
  command = plan
  variables {
    subnet_name = "GatewaySubnet"
  }
  expect_failures = [var.subnet_name]
}

run "invalid_subnet_name" {
  command = plan
  variables {
    subnet_name = "-nodes"
  }
  expect_failures = [var.subnet_name]
}

run "invalid_tags" {
  command = plan
  variables {
    tags = { "invalid/key" = "value" }
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
