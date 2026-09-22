variable "name" {
  description = "Virtual network name (1-64 characters)."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[A-Za-z0-9]([A-Za-z0-9_.-]{0,62}[A-Za-z0-9_])?$", var.name))
    error_message = "name must be 1-64 letters, digits, underscores, periods or hyphens; start alphanumeric and end alphanumeric or underscore."
  }
}

variable "address_space" {
  description = "One canonical IPv4 CIDR for the virtual network, /8 through /29."
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
  validation {
    condition = try(
      can(cidrnetmask(var.address_space)) &&
      cidrhost(var.address_space, 0) == split("/", var.address_space)[0] &&
      tonumber(split("/", var.address_space)[1]) >= 8 &&
      tonumber(split("/", var.address_space)[1]) <= 29, false
    )
    error_message = "address_space must be a canonical IPv4 CIDR with prefix length 8-29, such as 10.0.0.0/16."
  }
}

variable "subnet_name" {
  description = "Workload subnet name; Azure reserved subnet names are excluded."
  type        = string
  default     = "nodes"
  nullable    = false
  validation {
    condition = can(regex("^[A-Za-z0-9]([A-Za-z0-9_.-]{0,78}[A-Za-z0-9_])?$", var.subnet_name)) && !contains([
      "gatewaysubnet", "azurebastionsubnet", "azurefirewallsubnet", "azurefirewallmanagementsubnet", "routeserversubnet"
    ], lower(var.subnet_name))
    error_message = "subnet_name must be 1-80 valid Azure name characters and cannot be an Azure reserved subnet name."
  }
}

variable "subnet_prefix" {
  description = "Canonical IPv4 subnet CIDR contained in address_space, no smaller than /29."
  type        = string
  default     = "10.0.0.0/22"
  nullable    = false
  validation {
    condition = try(
      can(cidrnetmask(var.subnet_prefix)) &&
      cidrhost(var.subnet_prefix, 0) == split("/", var.subnet_prefix)[0] &&
      tonumber(split("/", var.subnet_prefix)[1]) >= tonumber(split("/", var.address_space)[1]) &&
      tonumber(split("/", var.subnet_prefix)[1]) <= 29 &&
      cidrhost("${split("/", var.subnet_prefix)[0]}/${split("/", var.address_space)[1]}", 0) == cidrhost(var.address_space, 0), false
    )
    error_message = "subnet_prefix must be a canonical IPv4 CIDR inside address_space, with prefix length at most 29."
  }
}
