variable "account_name" {
  type        = string
  description = "ARTESCA account that owns the bucket. Forces replacement."
}

variable "bucket_name" {
  type        = string
  description = "Bucket name. Forces replacement."
}

variable "retention_mode" {
  type        = string
  description = "Default retention mode: \"GOVERNANCE\" (users with s3:BypassGovernanceRetention can delete or shorten) or \"COMPLIANCE\" (nobody can delete a locked version until its retention ends)."

  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.retention_mode)
    error_message = "retention_mode must be \"GOVERNANCE\" or \"COMPLIANCE\"."
  }
}

variable "retention_days" {
  type        = number
  default     = null
  description = "Default retention in days. Set exactly one of retention_days and retention_years."
}

variable "retention_years" {
  type        = number
  default     = null
  description = "Default retention in years. Set exactly one of retention_days and retention_years."
}

variable "sse_algorithm" {
  type        = string
  default     = "AES256"
  description = "Default encryption: \"AES256\", or null for none."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Bucket tags, up to 50."
}

variable "abort_incomplete_multipart_upload_days" {
  type        = number
  default     = 7
  description = "Abort incomplete multipart uploads after this many days. Null disables."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Delete every object version on destroy, where retention allows (GOVERNANCE versions can be deleted; COMPLIANCE versions under retention stop the destroy). Apply before destroying."
}
