terraform {
  required_version = ">= 1.9.0, < 2.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.43.0, < 5.0.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  description = "Azure subscription UUID."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Existing Entra administrator group UUIDs."
  type        = set(string)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-node-pool-example"
  location = "eastus2"
}

module "node_pool" {
  source = "../.."
  # Git source: git::https://github.com/srjbis/terraform-modules.git//node-pool?ref=node-pool-v1.1.0

  name = "apps"
  aks = {
    name                   = "aks-pool-example"
    resource_group_name    = azurerm_resource_group.this.name
    location               = azurerm_resource_group.this.location
    dns_prefix             = "aks-pool-example"
    admin_group_object_ids = var.admin_group_object_ids
    network = {
      address_space = "172.20.0.0/16"
      subnet_prefix = "172.20.0.0/22"
    }
    system_node_pool        = { auto_scaling_enabled = false, node_count = 2 }
    node_os_upgrade_channel = "SecurityPatch"
    network_profile = {
      service_cidr   = "172.21.0.0/16"
      dns_service_ip = "172.21.0.53"
      pod_cidr       = "172.22.0.0/16"
    }
  }
  scaling = { min_count = 0, max_count = 5 }
  tags    = { environment = "example" }
}

output "aks_id" {
  value = module.node_pool.aks_id
}

output "node_pool_id" {
  value = module.node_pool.id
}

output "network_id" {
  value = module.node_pool.network_id
}
