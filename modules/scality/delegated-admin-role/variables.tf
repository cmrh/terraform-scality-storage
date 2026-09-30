variable "account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of the sub-account the role is created in — typically its account-root key from scality-account-management. Used only at bootstrap; afterwards the management account manages the sub-account through the role. Forces replacement."
}

variable "account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key paired with account_access_key. Forces replacement."
}

variable "trusted_user_arn" {
  type        = string
  description = "ARN of the single IAM user (in the management account) allowed to assume the role, e.g. \"arn:aws:iam::111111111111:user/delegator\". Must be a user ARN — account-root principals are rejected by design. Changing it replaces the role."

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:user/[^/]+$", var.trusted_user_arn))
    error_message = "trusted_user_arn must be an IAM user ARN of the form arn:aws:iam::<12-digit account id>:user/<name>. Account-root (…:root), bare account IDs, and path-style account ARNs are not accepted."
  }
}

variable "role_name" {
  type        = string
  default     = "account-manager"
  description = "Name of the IAM role. Forces replacement."
}

variable "policy_name" {
  type        = string
  default     = null
  description = "Name of the managed policy attached to the role. Defaults to \"<role_name>-perms\" when null. Forces replacement."
}

variable "policy_document" {
  type        = string
  default     = null
  description = "Custom JSON permissions policy for the role. Defaults to s3:* + iam:* on all resources in the sub-account when null. Updates apply in-place."
}
