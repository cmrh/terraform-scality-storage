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

variable "retention_mode" {
  type        = string
  description = "Object lock retention mode. \"GOVERNANCE\" allows users with s3:BypassGovernanceRetention permission to override or delete locks (suitable for testing or regulated overrides). \"COMPLIANCE\" prevents anyone — including the account root — from deleting locked objects until the retention period expires (suitable for regulatory WORM workloads). Choose explicitly: COMPLIANCE is irrevocable for the locked period."

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.retention_mode)
    error_message = "retention_mode must be either \"GOVERNANCE\" or \"COMPLIANCE\"."
  }
}

variable "retention_days" {
  type        = number
  default     = null
  description = "Default retention period in days. Set this OR retention_years (exactly one required)."
}

variable "retention_years" {
  type        = number
  default     = null
  description = "Default retention period in years. Set this OR retention_days (exactly one required)."
}

variable "abort_incomplete_multipart_upload_days" {
  type        = number
  default     = 7
  description = "Days after which incomplete multipart uploads are aborted (frees orphaned MPU parts). Set null to disable this rule."
}
