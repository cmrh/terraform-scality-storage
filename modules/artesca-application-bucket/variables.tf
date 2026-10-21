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

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Delete every object version when the bucket is destroyed. Apply before destroying."
}
