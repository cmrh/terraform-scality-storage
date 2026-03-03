variable "bucket_name" {
  description = "Name of the S3 bucket to configure lifecycle rules for"
  type        = string
}

variable "lifecycle_rules" {
  description = <<-EOT
    List of lifecycle rules to apply to the bucket. Each rule can contain:
    - id: Unique identifier for the rule (required)
    - enabled: Whether the rule is enabled (default: true)
    - filter: Object filter criteria (optional)
      - prefix: Prefix to filter objects (string)
      - tag: Single tag filter {key, value}
      - and: Combination filter {prefix, tags}
    - expiration: Expiration settings for current versions
      - days: Number of days after creation (int)
      - date: Specific date (ISO 8601 format)
      - expired_object_delete_marker: Delete expired object delete markers (bool)
    - noncurrent_version_expiration: Expiration for noncurrent versions
      - noncurrent_days: Days after becoming noncurrent (int)
    - abort_incomplete_multipart_upload: Abort incomplete multipart uploads
      - days_after_initiation: Days after initiation (int)

    NOTE: Transition policies are NOT supported by Scality
  EOT
  type = list(object({
    id      = string
    enabled = optional(bool, true)
    filter = optional(object({
      prefix = optional(string)
      tag = optional(object({
        key   = string
        value = string
      }))
      and = optional(object({
        prefix = optional(string)
        tags   = optional(map(string))
      }))
    }))
    expiration = optional(object({
      days                         = optional(number)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))
    noncurrent_version_expiration = optional(object({
      noncurrent_days = number
    }))
    abort_incomplete_multipart_upload = optional(object({
      days_after_initiation = number
    }))
  }))

  validation {
    condition = alltrue([
      for rule in var.lifecycle_rules :
      rule.expiration != null || rule.noncurrent_version_expiration != null || rule.abort_incomplete_multipart_upload != null
    ])
    error_message = "Each lifecycle rule must have at least one action: expiration, noncurrent_version_expiration, or abort_incomplete_multipart_upload."
  }

  validation {
    condition = alltrue([
      for rule in var.lifecycle_rules :
      rule.expiration == null ? true : (
        (rule.expiration.days != null && rule.expiration.date == null) ||
        (rule.expiration.days == null && rule.expiration.date != null) ||
        (rule.expiration.days == null && rule.expiration.date == null && rule.expiration.expired_object_delete_marker != null)
      )
    ])
    error_message = "Expiration must specify either 'days' OR 'date' OR only 'expired_object_delete_marker', not multiple options."
  }
}

variable "bucket_dependency" {
  description = "Optional dependency on bucket creation/configuration (e.g., aws_s3_bucket.example)"
  type        = any
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources (if applicable)"
  type        = map(string)
  default     = {}
}
