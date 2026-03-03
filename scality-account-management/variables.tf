variable "scality_endpoint" {
  description = "Scality S3/IAM endpoint URL (e.g., http://10.164.169.247)"
  type        = string
}

variable "access_key" {
  description = "Account admin access key. If not provided, will use AWS_ACCESS_KEY_ID environment variable"
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_key" {
  description = "Account admin secret key. If not provided, will use AWS_SECRET_ACCESS_KEY environment variable"
  type        = string
  default     = null
  sensitive   = true
}

variable "use_https" {
  description = "Use HTTPS for connections to Scality endpoint"
  type        = bool
  default     = false
}

variable "users" {
  description = <<-EOT
    Map of IAM users to create. Each user can have:
    - path: IAM path for the user (default: /)
    - tags: Map of tags
    - groups: List of group names to join
    - policies: List of policy names to attach
    - generate_access_key: Whether to generate access keys (default: true)
  EOT
  type = map(object({
    path                = optional(string, "/")
    tags                = optional(map(string), {})
    groups              = optional(list(string), [])
    policies            = optional(list(string), [])
    generate_access_key = optional(bool, true)
  }))
  default = {}
}

variable "groups" {
  description = <<-EOT
    Map of IAM groups to create. Each group can have:
    - path: IAM path for the group (default: /)
    - policies: List of policy names to attach
  EOT
  type = map(object({
    path     = optional(string, "/")
    policies = optional(list(string), [])
  }))
  default = {}
}

variable "policies" {
  description = <<-EOT
    Map of IAM policies to create. Each policy must have:
    - description: Policy description
    - policy_document: JSON policy document (can be file() or jsonencode())
    - path: IAM path for the policy (default: /)
  EOT
  type = map(object({
    description     = string
    policy_document = string
    path            = optional(string, "/")
  }))
  default = {}
}
