variable "account_name" {
  type        = string
  description = "ARTESCA account to create. Forces replacement."
}

variable "account_email" {
  type        = string
  description = "Email for the ARTESCA account. Forces replacement."
}

variable "bucket_name" {
  type        = string
  description = "Bucket on ARTESCA's default storage (us-east-1). Versioned; replicated to the RING S3 location."
}

variable "users" {
  type        = set(string)
  default     = []
  description = "IAM users to create in the account, each with an access key and read-write access to the bucket."
}

variable "mode" {
  type        = string
  default     = "ring-s3"
  description = "\"ring-s3\" (default): a RING S3 location writes with ring_s3_access_key. \"crr\": a CRR location assumes ring_s3_role_arn over STS (ring_s3_sts_endpoint) and the role writes the replicas. Changing it replaces the location."

  validation {
    condition     = contains(["ring-s3", "crr"], var.mode)
    error_message = "mode must be \"ring-s3\" or \"crr\"."
  }
}

variable "ring_s3_sts_endpoint" {
  type        = string
  default     = null
  description = "Scality S3 STS endpoint, as ARTESCA reaches it. Required for mode = \"crr\"."
}

variable "ring_s3_role_arn" {
  type        = string
  default     = null
  description = "Destination role on Scality S3 (scality-ring-s3-target's role_arn with purpose = \"crr\"). Required for mode = \"crr\"."
}

variable "location_name" {
  type        = string
  description = "Name of the RING S3 location to create. Locations are instance-wide, so include something unique (e.g. the bucket name)."
}

variable "ring_s3_endpoint" {
  type        = string
  description = "Scality S3 endpoint URL."
}

variable "ring_s3_bucket_name" {
  type        = string
  description = "Target bucket on Scality S3 (e.g. scality-ring-s3-target's bucket_name). Objects are written at its root (bucket_match = true)."
}

variable "ring_s3_access_key" {
  type        = string
  sensitive   = true
  description = "Scality S3 access key the location uses. Not the Scality S3 account's root key."
}

variable "ring_s3_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key matching ring_s3_access_key."
}

variable "replication_enabled" {
  type        = bool
  default     = true
  description = "Whether the replication rule is active."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Delete all object versions and detach user policies on destroy. Apply before destroying."
}
