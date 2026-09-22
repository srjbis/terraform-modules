variable "private_cluster_public_fqdn_enabled" {
  description = "Publish a public FQDN for a private cluster."
  type        = bool
  default     = false
  nullable    = false
  validation {
    condition     = !var.private_cluster_public_fqdn_enabled || var.api_access.private_cluster_enabled
    error_message = "private_cluster_public_fqdn_enabled requires a private cluster."
  }
}

variable "role_based_access_control_enabled" {
  description = "Enable Kubernetes RBAC and managed Entra integration."
  type        = bool
  default     = true
  nullable    = false
}

variable "local_account_disabled" {
  description = "Disable local cluster accounts; requires Kubernetes RBAC and Entra integration."
  type        = bool
  default     = true
  nullable    = false
  validation {
    condition     = !var.local_account_disabled || var.role_based_access_control_enabled
    error_message = "Disabling local accounts requires Kubernetes RBAC and managed Entra integration."
  }
}

variable "azure_policy_enabled" {
  description = "Enable the Azure Policy add-on."
  type        = bool
  default     = true
  nullable    = false
}

variable "oidc_issuer_enabled" {
  description = "Enable the OIDC issuer."
  type        = bool
  default     = true
  nullable    = false
}

variable "workload_identity_enabled" {
  description = "Enable workload identity; requires OIDC."
  type        = bool
  default     = true
  nullable    = false
  validation {
    condition     = !var.workload_identity_enabled || var.oidc_issuer_enabled
    error_message = "workload_identity_enabled requires oidc_issuer_enabled."
  }
}

variable "run_command_enabled" {
  description = "Enable AKS run-command access."
  type        = bool
  default     = false
  nullable    = false
}

variable "azure_rbac_enabled" {
  description = "Use Azure RBAC for authorization; false uses Kubernetes RBAC with Entra authentication."
  type        = bool
  default     = true
  nullable    = false
  validation {
    condition     = !var.azure_rbac_enabled || var.role_based_access_control_enabled
    error_message = "azure_rbac_enabled requires role_based_access_control_enabled."
  }
}

variable "node_os_upgrade_channel" {
  description = "Node OS update channel."
  type        = string
  default     = "NodeImage"
  nullable    = false
  validation {
    condition     = contains(["None", "Unmanaged", "SecurityPatch", "NodeImage"], var.node_os_upgrade_channel)
    error_message = "node_os_upgrade_channel must be None, Unmanaged, SecurityPatch or NodeImage."
  }
}

variable "identity_type" {
  description = "Cluster managed identity type. UserAssigned authorizes networking before cluster creation."
  type        = string
  default     = "UserAssigned"
  nullable    = false
  validation {
    condition     = contains(["UserAssigned", "SystemAssigned"], var.identity_type)
    error_message = "identity_type must be UserAssigned or SystemAssigned."
  }
}

variable "private_dns_zone_id" {
  description = "System, None, or an existing private DNS zone resource ID; only applied to private clusters."
  type        = string
  default     = "System"
  nullable    = false
  validation {
    condition     = contains(["System", "None"], var.private_dns_zone_id) || can(regex("(?i)^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/[^/]+/providers/Microsoft.Network/privateDnsZones/[^/]+$", var.private_dns_zone_id))
    error_message = "private_dns_zone_id must be System, None, or a full Azure private DNS zone resource ID."
  }
  validation {
    condition     = contains(["System", "None"], var.private_dns_zone_id) || (var.api_access.private_cluster_enabled && var.identity_type == "UserAssigned")
    error_message = "A custom private DNS zone requires a private cluster and UserAssigned identity."
  }
  validation {
    condition     = !var.api_access.private_cluster_enabled || var.private_dns_zone_id != "None" || var.private_cluster_public_fqdn_enabled
    error_message = "Private DNS None requires public FQDN enabled; this module does not configure custom DNS servers."
  }
}
