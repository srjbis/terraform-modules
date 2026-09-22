variable "tags" {
  description = "Tags applied to this pool and any cluster/network created by this module."
  type        = map(string)
  default     = {}
  nullable    = false
  validation {
    condition     = length(var.tags) <= 50 && alltrue([for key, value in var.tags : length(key) > 0 && length(key) <= 512 && can(regex("^[^<>%&\\\\?/]+$", key)) && (value == null ? false : length(value) <= 256)])
    error_message = "Use at most 50 tags with keys of 1-512 characters (no < > % & backslash ? /) and non-null values up to 256 characters."
  }
}
