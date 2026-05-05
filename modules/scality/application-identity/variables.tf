variable "account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of an account principal authorized to manage IAM users — typically the operator user from the account-operator module. Forces replacement."
}

variable "account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key paired with account_access_key. Forces replacement."
}

variable "username" {
  type        = string
  description = "IAM username. Forces replacement (Scality does not support renaming users)."
}

variable "access_pattern" {
  type        = string
  default     = "read-write"
  description = "Pre-canned access pattern. One of: \"read-only\" (s3:GetObject, s3:ListBucket and friends), \"read-write\" (default; adds s3:PutObject and s3:DeleteObject), \"bucket-admin\" (full s3:* on the specified buckets only). Ignored when policy_document is set. See README for the exact actions each preset grants."

  validation {
    condition     = contains(["read-only", "read-write", "bucket-admin"], var.access_pattern)
    error_message = "access_pattern must be one of: read-only, read-write, bucket-admin."
  }
}

variable "bucket_arns" {
  type        = list(string)
  default     = []
  description = "List of bucket ARNs the user gets access to under the chosen access_pattern. Required when using a preset; ignored when policy_document is set. Example: [\"arn:aws:s3:::acme-data\"]."
}

variable "policy_document" {
  type        = string
  default     = null
  description = "Custom JSON IAM policy document for use cases not covered by the presets. When set, overrides access_pattern and bucket_arns. Construct with jsonencode(...), file(\"path/to/policy.json\"), or templatefile(...). Updates apply in-place."
}

variable "policy_name" {
  type        = string
  default     = null
  description = "Name of the inline policy. Defaults to \"<username>-policy\" when null."
}
