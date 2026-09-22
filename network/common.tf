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

variable "tags" {
  description = "Tags applied to the virtual network; Azure subnets do not support tags."
  type        = map(string)
  default     = {}
  nullable    = false
  validation {
    condition     = length(var.tags) <= 50 && alltrue([for key, value in var.tags : length(key) > 0 && length(key) <= 512 && can(regex("^[^<>%&\\\\?/]+$", key)) && (value == null ? false : length(value) <= 256)])
    error_message = "Use at most 50 tags with keys of 1-512 characters (no < > % & backslash ? /) and non-null values up to 256 characters."
  }
}
