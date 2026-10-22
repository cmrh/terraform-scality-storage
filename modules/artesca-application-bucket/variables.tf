variable "account_name" {
  type        = string
  description = "ARTESCA account that owns the bucket. Forces replacement."
}

variable "bucket_name" {
  type        = string
  description = "Bucket name: 3-63 lowercase letters, numbers, hyphens and periods. Forces replacement."
}

variable "location_constraint" {
  type        = string
  default     = null
  description = "ARTESCA location that stores the bucket's data. Null (default) uses ARTESCA's own storage. Forces replacement."
}

variable "versioning" {
  type        = bool
  default     = true
  description = "Enable versioning. When false, the module leaves versioning unmanaged instead of suspending it."
}

variable "sse_algorithm" {
  type        = string
  default     = "AES256"
  description = "Default encryption: \"AES256\", or null to leave the bucket without a default encryption configuration."

  validation {
    condition     = var.sse_algorithm == null || var.sse_algorithm == "AES256"
    error_message = "sse_algorithm must be \"AES256\" or null."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Bucket tags, up to 50. Empty (default) manages no tags."

  validation {
    condition     = length(var.tags) <= 50
    error_message = "A bucket can have at most 50 tags."
  }
}

variable "expiration_days" {
  type        = number
  default     = null
  description = "Expire current object versions this many days after creation. On a versioned bucket this adds a delete marker; older versions remain. Null (default) adds no expiration rule."

  validation {
    condition     = var.expiration_days == null || try(var.expiration_days >= 1 && floor(var.expiration_days) == var.expiration_days, false)
    error_message = "expiration_days must be a whole number of at least 1, or null."
  }
}

variable "expiration_prefix" {
  type        = string
  default     = null
  description = "Only expire objects whose key starts with this prefix. Null (default) applies the rule to all objects."
}

variable "noncurrent_version_expiration_days" {
  type        = number
  default     = 90
  description = "Delete versions this many days after they become noncurrent. Null disables."

  validation {
    condition     = var.noncurrent_version_expiration_days == null || try(var.noncurrent_version_expiration_days >= 1 && floor(var.noncurrent_version_expiration_days) == var.noncurrent_version_expiration_days, false)
    error_message = "noncurrent_version_expiration_days must be a whole number of at least 1, or null."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  type        = number
  default     = 7
  description = "Abort incomplete multipart uploads this many days after they start, deleting their parts. Null disables."

  validation {
    condition     = var.abort_incomplete_multipart_upload_days == null || try(var.abort_incomplete_multipart_upload_days >= 1 && floor(var.abort_incomplete_multipart_upload_days) == var.abort_incomplete_multipart_upload_days, false)
    error_message = "abort_incomplete_multipart_upload_days must be a whole number of at least 1, or null."
  }
}

variable "expire_delete_markers" {
  type        = bool
  default     = false
  description = "Remove delete markers that have no noncurrent versions left behind them."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Delete every object version when the bucket is destroyed. Apply before destroying."
}
