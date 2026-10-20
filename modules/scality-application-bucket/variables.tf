variable "account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of an account principal authorized to manage buckets — typically the operator user from the account-operator module. Forces replacement."
}

variable "account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key paired with account_access_key. Forces replacement."
}

variable "bucket_name" {
  type        = string
  description = "Bucket name. 3-63 chars, lowercase + digits + hyphens + periods. Forces replacement."
}

variable "versioning" {
  type        = bool
  default     = true
  description = "Enable bucket versioning. Strongly recommended for production — protects against accidental overwrites and deletions. Combine with noncurrent_version_expiration_days to keep storage costs in check."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the bucket."
}

variable "sse_algorithm" {
  type        = string
  default     = "AES256"
  description = "Server-side encryption algorithm. Use \"AES256\" (SSE-S3) for every standard deployment. \"aws:kms\" requires an external KMS configured on the cluster."

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be either \"AES256\" or \"aws:kms\"."
  }
}

variable "kms_master_key_id" {
  type        = string
  default     = null
  description = "KMS key ID. Required when sse_algorithm = \"aws:kms\", ignored otherwise."
}

variable "abort_incomplete_multipart_upload_days" {
  type        = number
  default     = 7
  description = "Days after which incomplete multipart uploads are aborted (frees orphaned MPU parts). Set null to disable this rule."
}

variable "noncurrent_version_expiration_days" {
  type        = number
  default     = 90
  description = "Days after which superseded object versions are permanently deleted. Set null to disable. Only meaningful when versioning is enabled."
}

variable "expiration_days" {
  type        = number
  default     = null
  description = "Days after which current objects expire (delete). Default null = retain indefinitely. Common values: 30 for short-lived logs, 365 for retention-driven workloads."
}
