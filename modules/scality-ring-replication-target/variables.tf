variable "account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of a principal in the RING account that owns the target bucket, typically the operator from account-operator."
}

variable "account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key matching account_access_key."
}

variable "bucket_name" {
  type        = string
  description = "Target bucket for replicated objects. One per ARTESCA source bucket."
}

variable "username" {
  type        = string
  default     = "artesca-replication"
  description = "IAM user whose key ARTESCA's location uses. It can only write to the bucket."
}

variable "policy_name" {
  type        = string
  default     = "artesca-replication"
  description = "Inline policy on the replication user."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for the bucket."
}
