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
  description = "Target Azure subscription UUID."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Existing Entra administrator group UUIDs."
  type        = set(string)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-aks-example"
  location = "eastus2"
}

module "aks" {
  source = "../.."
  # For consumers after release, replace source with:
  # source = "git::https://github.com/srjbis/terraform-modules.git//aks?ref=aks-v2.0.0"

  name                   = "aks-example"
  resource_group_name    = azurerm_resource_group.this.name
  location               = azurerm_resource_group.this.location
  dns_prefix             = "aks-example"
  admin_group_object_ids = var.admin_group_object_ids
  network = {
    address_space = "172.20.0.0/16"
    subnet_prefix = "172.20.0.0/22"
  }
  tags = { environment = "example" }
}

output "cluster_id" {
  value = module.aks.id
}
