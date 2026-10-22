variable "account_name" {
  type        = string
  description = "ARTESCA account that owns the bucket. Forces replacement."
}

variable "bucket_name" {
  type        = string
  description = "Bucket name. Forces replacement."
}

variable "transition_location" {
  type        = string
  description = "Location objects move to, e.g. artesca-storage-location's name."
}

variable "transition_days" {
  type        = number
  description = "Days after creation when objects move. 0 moves them at the next lifecycle run."

  validation {
    condition     = try(var.transition_days >= 0 && floor(var.transition_days) == var.transition_days, false)
    error_message = "transition_days must be a whole number of at least 0."
  }
}

variable "transition_prefix" {
  type        = string
  default     = null
  description = "Only move objects whose key starts with this prefix. Null (default) moves all objects."
}

variable "noncurrent_transition_days" {
  type        = number
  default     = null
  description = "Also move versions to transition_location this many days after they become noncurrent. Must be lower than noncurrent_version_expiration_days. Null (default) moves current versions only."

  validation {
    condition     = var.noncurrent_transition_days == null || try(var.noncurrent_transition_days >= 0 && floor(var.noncurrent_transition_days) == var.noncurrent_transition_days, false)
    error_message = "noncurrent_transition_days must be a whole number of at least 0, or null."
  }
}

variable "noncurrent_version_expiration_days" {
  type        = number
  default     = 90
  description = "Delete versions this many days after they become noncurrent. Null keeps them."
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

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Delete every object version when the bucket is destroyed. Apply before destroying."
}
