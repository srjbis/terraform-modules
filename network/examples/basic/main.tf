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

resource "azurerm_resource_group" "this" {
  name     = "rg-network-example"
  location = "eastus2"
}

module "network" {
  source = "../.."
  # Git source: git::https://github.com/srjbis/terraform-modules.git//network?ref=network-v1.0.0

  name                = "vnet-example"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  address_space       = "172.20.0.0/16"
  subnet_prefix       = "172.20.0.0/22"
  tags                = { environment = "example" }
}

output "subnet_id" {
  value = module.network.subnet_id
}
