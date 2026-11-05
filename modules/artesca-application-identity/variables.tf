variable "account_name" {
  type        = string
  description = "ARTESCA account that owns the user (e.g. artesca-account-management's account_name). Forces replacement."
}

variable "username" {
  type        = string
  description = "IAM username: 1-64 characters, letters, numbers and +=,.@-. Forces replacement."
}

variable "access_pattern" {
  type        = string
  default     = "read-write"
  description = "Preset policy: \"read-only\", \"read-write\" (default) or \"bucket-admin\", over bucket_arns. Ignored when policy_document is set. See README for the actions each grants."

  validation {
    condition     = contains(["read-only", "read-write", "bucket-admin"], var.access_pattern)
    error_message = "access_pattern must be one of: read-only, read-write, bucket-admin."
  }
}

variable "bucket_arns" {
  type        = list(string)
  default     = []
  description = "Bucket ARNs the preset applies to, e.g. [\"arn:aws:s3:::app-data\"]. Required with a preset; ignored when policy_document is set."
}

variable "policy_document" {
  type        = string
  default     = null
  description = "Custom JSON policy document. Overrides access_pattern and bucket_arns. Updates apply in place."
}

variable "policy_name" {
  type        = string
  default     = null
  description = "Name of the inline policy. Defaults to \"<username>-policy\"."
}

variable "policies" {
  type        = map(string)
  default     = {}
  description = "Further inline policies: policy name => JSON document, alongside the preset or policy_document policy. Construct documents with jsonencode(...) or file(...). With no bucket_arns, policy_document, policies or policy_arns, the user has no policy."
}

variable "policy_arns" {
  type        = map(string)
  default     = {}
  description = "Managed policies to attach to the user: any static key => policy ARN. A map rather than a list so an ARN created in the same apply still works (for_each keys must be known at plan time)."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Detach policies and group memberships not managed here when the user is destroyed. Apply before destroying."
}
