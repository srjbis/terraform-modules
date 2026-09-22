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
  description = "Subscription containing the existing AKS cluster."
  type        = string
}

variable "aks_id" {
  description = "Full resource ID of an existing AKS cluster."
  type        = string
}

module "node_pool" {
  source = "../.."
  # Git source: git::https://github.com/srjbis/terraform-modules.git//node-pool?ref=node-pool-v1.1.0

  name         = "apps"
  existing_aks = { id = var.aks_id }
  scaling      = { min_count = 0, max_count = 5 }
  tags         = { environment = "example" }
}

output "node_pool_id" {
  value = module.node_pool.id
}
