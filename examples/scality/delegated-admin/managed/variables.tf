variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for bucket and user names. Use the same value as the bootstrap stage."
}

variable "delegator_access_key" {
  type        = string
  sensitive   = true
  description = "Management user's access key (bootstrap output delegator_access_key)."
}

variable "delegator_secret_key" {
  type        = string
  sensitive   = true
  description = "Management user's secret key (bootstrap output delegator_secret_key)."
}

variable "role_arns" {
  type        = map(string)
  description = "Delegated-admin role ARN per sub-account (bootstrap output role_arns). Must contain customer-a and customer-b."
}
