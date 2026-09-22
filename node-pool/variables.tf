variable "existing_aks" {
  description = "Existing cluster to read and verify. Null creates AKS and its network using aks configuration. Object presence must be known at plan time."
  type        = object({ id = string })
  default     = null
  validation {
    condition = var.existing_aks == null ? true : can(regex(
      "(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+/providers/Microsoft.ContainerService/managedClusters/[^/]+$",
      var.existing_aks.id
    ))
    error_message = "existing_aks.id must be a full Azure AKS resource ID with a subscription UUID."
  }
}

variable "aks" {
  description = "Configuration for creating AKS and networking. Required only when existing_aks is null. Child modules enforce cluster and network guardrails."
  type = object({
    name                                = string
    resource_group_name                 = string
    location                            = string
    dns_prefix                          = string
    admin_group_object_ids              = set(string)
    kubernetes_version                  = optional(string)
    sku_tier                            = optional(string, "Standard")
    private_cluster_public_fqdn_enabled = optional(bool, false)
    role_based_access_control_enabled   = optional(bool, true)
    local_account_disabled              = optional(bool, true)
    azure_policy_enabled                = optional(bool, true)
    oidc_issuer_enabled                 = optional(bool, true)
    workload_identity_enabled           = optional(bool, true)
    run_command_enabled                 = optional(bool, false)
    azure_rbac_enabled                  = optional(bool, true)
    node_os_upgrade_channel             = optional(string, "NodeImage")
    identity_type                       = optional(string, "UserAssigned")
    private_dns_zone_id                 = optional(string, "System")
    network_profile = optional(object({
      network_plugin      = optional(string, "azure")
      network_plugin_mode = optional(string, "overlay")
      network_policy      = optional(string, "calico")
      network_data_plane  = optional(string, "azure")
      load_balancer_sku   = optional(string, "standard")
      outbound_type       = optional(string, "loadBalancer")
      service_cidr        = optional(string, "10.1.0.0/16")
      dns_service_ip      = optional(string, "10.1.0.10")
      pod_cidr            = optional(string, "10.244.0.0/16")
    }), {})
    api_access = optional(object({
      private_cluster_enabled = optional(bool, true)
      authorized_ip_ranges    = optional(set(string), [])
    }), {})
    system_node_pool = optional(object({
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
    }), {})
    network = optional(object({
      address_space = optional(string, "10.0.0.0/16")
      subnet_prefix = optional(string, "10.0.0.0/22")
      subnet_name   = optional(string, "nodes")
    }), {})
  })
  default = null
  validation {
    condition     = (var.existing_aks == null) != (var.aks == null)
    error_message = "Supply exactly one of existing_aks or aks: an existing cluster ID, or configuration to create a cluster and network."
  }
}

variable "name" {
  description = "Additional Linux node pool name, 1-11 lowercase alphanumeric characters; letter first. The module reserves name+r for rotation."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9]{0,10}$", var.name)) && !contains(["rotation", "rotatio"], var.name)
    error_message = "name must be 1-11 lowercase letters/digits, beginning with a letter, and cannot be rotation or rotatio."
  }
  validation {
    condition     = var.aks == null ? true : alltrue([for reserved in [var.aks.system_node_pool.name, var.aks.system_node_pool.temporary_name_for_rotation] : !contains([var.name, "${var.name}r"], reserved)])
    error_message = "The additional pool and its rotation name must differ from the new AKS system pool name."
  }
}

variable "vm_size" {
  description = "Azure VM SKU; Azure checks regional availability and capacity."
  type        = string
  default     = "Standard_D4s_v5"
  nullable    = false
  validation {
    condition     = can(regex("^Standard_[A-Za-z0-9_]+$", var.vm_size))
    error_message = "vm_size must use Azure Standard_ VM SKU syntax."
  }
}

variable "scaling" {
  description = "User-pool autoscaler bounds. Zero minimum allows scaling to zero."
  type = object({
    min_count = optional(number, 1)
    max_count = optional(number, 5)
  })
  default  = {}
  nullable = false
  validation {
    condition = (
      var.scaling.min_count >= 0 && var.scaling.max_count >= 1 && var.scaling.max_count <= 1000 &&
      var.scaling.min_count <= var.scaling.max_count &&
      floor(var.scaling.min_count) == var.scaling.min_count && floor(var.scaling.max_count) == var.scaling.max_count
    )
    error_message = "scaling must contain integers with 0 <= min_count <= max_count and 1 <= max_count <= 1000."
  }
}

variable "zones" {
  description = "Optional availability zones; Azure checks regional support."
  type        = set(string)
  default     = []
  nullable    = false
  validation {
    condition     = alltrue([for zone in var.zones : zone == null ? false : contains(["1", "2", "3"], zone)])
    error_message = "zones may contain only 1, 2 or 3; null entries are not allowed."
  }
}
