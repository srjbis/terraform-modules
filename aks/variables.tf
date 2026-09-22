variable "name" {
  description = "AKS cluster name: 1-63 letters, digits, underscores or hyphens; start and end with alphanumeric."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9_-]{0,61}[A-Za-z0-9])?$", var.name))
    error_message = "name must be 1-63 characters, start/end with alphanumeric, and contain only letters, digits, underscores or hyphens."
  }
}

variable "resource_group_name" {
  description = "Name of an existing resource group."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9_().-]{1,90}$", var.resource_group_name)) && !endswith(var.resource_group_name, ".")
    error_message = "resource_group_name must be 1-90 letters, digits, underscores, parentheses, hyphens or periods, and cannot end with a period."
  }
}

variable "location" {
  description = "Azure region identifier, for example eastus2. Availability is checked by Azure."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9]+$", var.location))
    error_message = "location must be a lowercase Azure region identifier such as eastus2."
  }
}

variable "dns_prefix" {
  description = "DNS prefix: 1-54 alphanumeric or hyphen characters."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,52}[A-Za-z0-9])?$", var.dns_prefix))
    error_message = "dns_prefix must be 1-54 alphanumeric or hyphen characters, starting and ending with alphanumeric."
  }
}

variable "kubernetes_version" {
  description = "Optional major.minor or major.minor.patch version. Null lets Azure select its recommended version."
  type        = string
  default     = null
  validation {
    condition     = var.kubernetes_version == null ? true : can(regex("^1\\.[0-9]+(\\.[0-9]+)?$", var.kubernetes_version))
    error_message = "kubernetes_version must be null or a version such as 1.34 or 1.34.1; Azure verifies regional support."
  }
}

variable "sku_tier" {
  description = "Cluster pricing tier. This module supports Free or Standard (no long-term support configuration)."
  type        = string
  default     = "Standard"
  nullable    = false
  validation {
    condition     = contains(["Free", "Standard"], var.sku_tier)
    error_message = "sku_tier must be Free or Standard."
  }
}

variable "admin_group_object_ids" {
  description = "Nonempty set of Entra ID group object UUIDs for cluster administrators."
  type        = set(string)
  nullable    = false
  validation {
    condition     = length(var.admin_group_object_ids) > 0 && alltrue([for id in var.admin_group_object_ids : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))])
    error_message = "admin_group_object_ids must contain at least one valid UUID."
  }
}

variable "api_access" {
  description = "Private by default. Public access requires explicit IPv4 CIDRs; /0 is prohibited. Private mode does not accept public IP ranges."
  type = object({
    private_cluster_enabled = optional(bool, true)
    authorized_ip_ranges    = optional(set(string), [])
  })
  default  = {}
  nullable = false
  validation {
    condition = var.api_access.private_cluster_enabled ? length(var.api_access.authorized_ip_ranges) == 0 : (
      length(var.api_access.authorized_ip_ranges) > 0 && alltrue([
        for cidr in var.api_access.authorized_ip_ranges : can(cidrnetmask(cidr)) && try(tonumber(split("/", cidr)[1]) > 0, false)
      ])
    )
    error_message = "Private clusters must have no authorized_ip_ranges; public clusters require valid IPv4 CIDRs with prefix lengths 1-32."
  }
}

variable "system_node_pool" {
  description = "Linux system pool. Defaults to autoscaling; disable it and set node_count for fixed sizing."
  type = object({
    name                        = optional(string, "system")
    vm_size                     = optional(string, "Standard_D4s_v5")
    min_count                   = optional(number, 2)
    max_count                   = optional(number, 5)
    zones                       = optional(set(string), [])
    temporary_name_for_rotation = optional(string, "rotation")
    auto_scaling_enabled        = optional(bool, true)
    node_count                  = optional(number, 2)
    os_sku                      = optional(string, "Ubuntu")
    node_public_ip_enabled      = optional(bool, false)
  })
  default  = {}
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,11}$", var.system_node_pool.name)) && var.system_node_pool.name != var.system_node_pool.temporary_name_for_rotation
    error_message = "System pool name must be 1-12 lowercase alphanumeric characters, begin with a letter and differ from temporary_name_for_rotation."
  }
  validation {
    condition     = can(regex("^Standard_[A-Za-z0-9_]+$", var.system_node_pool.vm_size))
    error_message = "vm_size must be an Azure Standard_ VM SKU; regional availability and system-pool suitability are checked by Azure."
  }
  validation {
    condition = alltrue([
      var.system_node_pool.min_count >= 1,
      var.system_node_pool.max_count <= 1000,
      var.system_node_pool.min_count <= var.system_node_pool.max_count,
      floor(var.system_node_pool.min_count) == var.system_node_pool.min_count,
      floor(var.system_node_pool.max_count) == var.system_node_pool.max_count
    ])
    error_message = "Pool counts must be integers satisfying 1 <= min_count <= max_count <= 1000."
  }
  validation {
    condition     = alltrue([for zone in var.system_node_pool.zones : zone == null ? false : contains(["1", "2", "3"], zone)])
    error_message = "zones may contain only 1, 2 and 3. Confirm availability in your region."
  }
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,11}$", var.system_node_pool.temporary_name_for_rotation))
    error_message = "temporary_name_for_rotation must be 1-12 lowercase alphanumeric characters starting with a letter."
  }
  validation {
    condition     = var.system_node_pool.node_count >= 1 && var.system_node_pool.node_count <= 1000 && floor(var.system_node_pool.node_count) == var.system_node_pool.node_count
    error_message = "node_count must be an integer from 1 to 1000 (used only when autoscaling is disabled)."
  }
  validation {
    condition     = contains(["Ubuntu", "AzureLinux"], var.system_node_pool.os_sku)
    error_message = "The Linux system pool supports os_sku Ubuntu or AzureLinux."
  }
}

variable "tags" {
  description = "Tags applied to the cluster, system pool, identity and virtual network."
  type        = map(string)
  default     = {}
  nullable    = false
  validation {
    condition     = length(var.tags) <= 50 && alltrue([for key, value in var.tags : length(key) > 0 && length(key) <= 512 && can(regex("^[^<>%&\\\\?/]+$", key)) && (value == null ? false : length(value) <= 256)])
    error_message = "Use at most 50 tags with keys of 1-512 characters (no < > % & backslash ? /) and non-null values up to 256 characters."
  }
}

variable "network" {
  description = "Network created with AKS. CIDRs must not overlap the configured service or active pod ranges."
  type = object({
    address_space = optional(string, "10.0.0.0/16")
    subnet_prefix = optional(string, "10.0.0.0/22")
    subnet_name   = optional(string, "nodes")
  })
  default  = {}
  nullable = false
  validation {
    condition = try(alltrue([for reserved in concat([var.network_profile.service_cidr], local.uses_pod_cidr ? [var.network_profile.pod_cidr] : []) :
      cidrhost("${split("/", var.network.address_space)[0]}/${min(tonumber(split("/", var.network.address_space)[1]), tonumber(split("/", reserved)[1]))}", 0) !=
      cidrhost("${split("/", reserved)[0]}/${min(tonumber(split("/", var.network.address_space)[1]), tonumber(split("/", reserved)[1]))}", 0)
    ]), false)
    error_message = "network.address_space must not overlap the configured service_cidr or active pod_cidr."
  }
}
