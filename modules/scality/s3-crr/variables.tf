variable "source_account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of the source-cluster account principal authorized to manage the source bucket and IAM resources — typically the operator user from account-operator on the source cluster. Forces replacement."
}

variable "source_account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key paired with source_account_access_key. Forces replacement."
}

variable "source_bucket_name" {
  type        = string
  description = "Name of the source bucket. Must already exist with versioning enabled (e.g., created via the application-bucket module on the source cluster)."
}

variable "dest_account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of the destination-cluster account principal authorized to manage the destination bucket and IAM resources — typically the operator user from account-operator on the destination cluster. Forces replacement."
}

variable "dest_account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key paired with dest_account_access_key. Forces replacement."
}

variable "dest_bucket_name" {
  type        = string
  description = "Name of the destination bucket. Must already exist with versioning enabled."
}

variable "bidirectional" {
  type        = bool
  default     = false
  description = "When true, also creates a reverse replication configuration (dest → source), giving active-active synchronization across both clusters. Default is one-direction (source → dest only)."
}

variable "role_name" {
  type        = string
  default     = "crr-role"
  description = "Name of the IAM role created on each cluster for the backbeat service to assume."
}

variable "policy_name" {
  type        = string
  default     = "crr-policy"
  description = "Name of the IAM managed policy created on each cluster granting replication permissions."
}
