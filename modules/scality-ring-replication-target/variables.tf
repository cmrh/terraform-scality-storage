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

variable "purpose" {
  type        = string
  default     = "replication"
  description = "How ARTESCA uses the bucket: \"replication\" (default; write-only key), \"tiering\" (the key can also read and delete objects) or \"crr\" (the key can only assume a destination role that writes the replicas)."

  validation {
    condition     = contains(["replication", "tiering", "crr"], var.purpose)
    error_message = "purpose must be \"replication\", \"tiering\" or \"crr\"."
  }
}

variable "role_name" {
  type        = string
  default     = "artesca-crr"
  description = "Destination role name, for purpose = \"crr\"."
}

variable "username" {
  type        = string
  default     = "artesca-replication"
  description = "IAM user whose key ARTESCA's location uses. Its permissions depend on purpose."
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
