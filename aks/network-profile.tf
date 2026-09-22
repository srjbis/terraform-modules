locals {
  uses_pod_cidr = var.network_profile.network_plugin == "kubenet" || var.network_profile.network_plugin_mode == "overlay"
}

variable "network_profile" {
  description = "AKS networking. Use none to omit plugin mode or policy. Flat Azure CNI omits pod_cidr. NAT egress creates and attaches a NAT gateway."
  type = object({
    network_plugin      = optional(string, "azure")
    network_plugin_mode = optional(string, "overlay")
    network_policy      = optional(string, "calico")
    network_data_plane  = optional(string, "azure")
    load_balancer_sku   = optional(string, "standard")
    outbound_type       = optional(string, "loadBalancer")
    service_cidr        = optional(string, "10.1.0.0/16")
    dns_service_ip      = optional(string, "10.1.0.10")
    pod_cidr            = optional(string, "10.244.0.0/16")
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["azure", "kubenet"], var.network_profile.network_plugin)
    error_message = "network_plugin must be azure or kubenet; bring-your-own CNI is not supported by this module."
  }
  validation {
    condition     = contains(["overlay", "none"], var.network_profile.network_plugin_mode) && (var.network_profile.network_plugin_mode != "overlay" || var.network_profile.network_plugin == "azure")
    error_message = "network_plugin_mode must be overlay or none; overlay requires the azure plugin."
  }
  validation {
    condition = contains(["azure", "calico", "cilium", "none"], var.network_profile.network_policy) && (
      var.network_profile.network_policy != "azure" || (var.network_profile.network_plugin == "azure" && var.network_profile.network_plugin_mode == "none")
    )
    error_message = "network_policy must be azure, calico, cilium or none; Azure policy requires flat Azure CNI (plugin azure, mode none)."
  }
  validation {
    condition = contains(["azure", "cilium"], var.network_profile.network_data_plane) && (
      var.network_profile.network_data_plane == "cilium" ? (
        var.network_profile.network_plugin == "azure" && var.network_profile.network_plugin_mode == "overlay" && contains(["cilium", "none"], var.network_profile.network_policy)
      ) : var.network_profile.network_policy != "cilium"
    )
    error_message = "Cilium policy requires the cilium data plane; this module supports that data plane only with Azure overlay and cilium or none policy."
  }
  validation {
    condition     = var.network_profile.load_balancer_sku == "standard"
    error_message = "load_balancer_sku must be standard; Basic Load Balancer is retired for AKS."
  }
  validation {
    condition     = contains(["loadBalancer", "userAssignedNATGateway"], var.network_profile.outbound_type)
    error_message = "outbound_type must be loadBalancer or userAssignedNATGateway. Managed NAT requires an Azure-managed VNet; custom routing and isolated bootstrapping are not provided by this module."
  }
  validation {
    condition = try(
      can(cidrnetmask(var.network_profile.service_cidr)) &&
      cidrhost(var.network_profile.service_cidr, 0) == split("/", var.network_profile.service_cidr)[0] &&
      tonumber(split("/", var.network_profile.service_cidr)[1]) >= 13 &&
      tonumber(split("/", var.network_profile.service_cidr)[1]) <= 29, false
    )
    error_message = "service_cidr must be a canonical IPv4 CIDR with prefix length 13-29."
  }
  validation {
    condition = try(
      can(cidrnetmask(var.network_profile.pod_cidr)) &&
      cidrhost(var.network_profile.pod_cidr, 0) == split("/", var.network_profile.pod_cidr)[0] &&
      tonumber(split("/", var.network_profile.pod_cidr)[1]) >= 8 &&
      tonumber(split("/", var.network_profile.pod_cidr)[1]) <= 24, false
    )
    error_message = "pod_cidr must be a canonical IPv4 CIDR with prefix length 8-24; it is used only by overlay or kubenet."
  }
  validation {
    condition = try(
      can(cidrnetmask("${var.network_profile.dns_service_ip}/32")) &&
      cidrhost("${var.network_profile.dns_service_ip}/${split("/", var.network_profile.service_cidr)[1]}", 0) == cidrhost(var.network_profile.service_cidr, 0) &&
      !contains([cidrhost(var.network_profile.service_cidr, 0), cidrhost(var.network_profile.service_cidr, 1), cidrhost(var.network_profile.service_cidr, -1)], var.network_profile.dns_service_ip), false
    )
    error_message = "dns_service_ip must be an IPv4 address inside service_cidr, excluding network, broadcast and the first address reserved for Kubernetes."
  }
  validation {
    condition = !(var.network_profile.network_plugin == "kubenet" || var.network_profile.network_plugin_mode == "overlay") ? true : try(
      cidrhost("${split("/", var.network_profile.service_cidr)[0]}/${min(tonumber(split("/", var.network_profile.service_cidr)[1]), tonumber(split("/", var.network_profile.pod_cidr)[1]))}", 0) !=
      cidrhost("${split("/", var.network_profile.pod_cidr)[0]}/${min(tonumber(split("/", var.network_profile.service_cidr)[1]), tonumber(split("/", var.network_profile.pod_cidr)[1]))}", 0), false
    )
    error_message = "service_cidr and active pod_cidr must not overlap."
  }
}
