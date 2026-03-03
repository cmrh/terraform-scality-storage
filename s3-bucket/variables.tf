# Bucket Configuration
variable "bucket_name" {
  description = "Name of the S3 bucket to create (must be globally unique)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.bucket_name)) && length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "Bucket name must be between 3-63 characters, start and end with lowercase letter or number, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "force_destroy" {
  description = "Allow bucket to be destroyed even if it contains objects (USE WITH CAUTION)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}

# Versioning Configuration
variable "versioning_enabled" {
  description = "Enable versioning on the bucket (true = Enabled, false = Suspended, null = not configured)"
  type        = bool
  default     = null
}

# Encryption Configuration
variable "enable_encryption" {
  description = "Enable default server-side encryption for the bucket"
  type        = bool
  default     = false
}

variable "encryption_algorithm" {
  description = "Server-side encryption algorithm (AES256 or aws:kms)"
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_algorithm)
    error_message = "Encryption algorithm must be either 'AES256' or 'aws:kms'."
  }
}

variable "kms_master_key_id" {
  description = "KMS master key ID (required if encryption_algorithm is aws:kms)"
  type        = string
  default     = null
}

# ACL Configuration
variable "acl" {
  description = "Canned ACL to apply to the bucket (private, public-read, public-read-write, authenticated-read, bucket-owner-read, bucket-owner-full-control)"
  type        = string
  default     = null

  validation {
    condition = var.acl == null || contains([
      "private",
      "public-read",
      "public-read-write",
      "authenticated-read",
      "bucket-owner-read",
      "bucket-owner-full-control"
    ], var.acl)
    error_message = "ACL must be one of: private, public-read, public-read-write, authenticated-read, bucket-owner-read, bucket-owner-full-control."
  }
}

# Object Ownership
variable "object_ownership" {
  description = "Object ownership setting (BucketOwnerPreferred, ObjectWriter, BucketOwnerEnforced)"
  type        = string
  default     = null

  validation {
    condition = var.object_ownership == null || contains([
      "BucketOwnerPreferred",
      "ObjectWriter",
      "BucketOwnerEnforced"
    ], var.object_ownership)
    error_message = "Object ownership must be one of: BucketOwnerPreferred, ObjectWriter, BucketOwnerEnforced."
  }
}

# Bucket Policy
variable "bucket_policy" {
  description = "Bucket policy JSON document"
  type        = string
  default     = null
}

# Public Access Block
variable "enable_public_access_block" {
  description = "Enable public access block configuration"
  type        = bool
  default     = true
}

variable "block_public_acls" {
  description = "Block public ACLs"
  type        = bool
  default     = true
}

variable "block_public_policy" {
  description = "Block public bucket policies"
  type        = bool
  default     = true
}

variable "ignore_public_acls" {
  description = "Ignore public ACLs"
  type        = bool
  default     = true
}

variable "restrict_public_buckets" {
  description = "Restrict public bucket policies"
  type        = bool
  default     = true
}

# CORS Configuration
variable "cors_rules" {
  description = <<-EOT
    List of CORS rules. Each rule can have:
    - id: Unique identifier (optional)
    - allowed_headers: List of allowed headers (optional)
    - allowed_methods: List of allowed methods (required) - GET, PUT, POST, DELETE, HEAD
    - allowed_origins: List of allowed origins (required)
    - expose_headers: List of headers to expose (optional)
    - max_age_seconds: Cache duration in seconds (optional)
  EOT
  type = list(object({
    id              = optional(string)
    allowed_headers = optional(list(string))
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string))
    max_age_seconds = optional(number)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.cors_rules :
      alltrue([for method in rule.allowed_methods : contains(["GET", "PUT", "POST", "DELETE", "HEAD"], method)])
    ])
    error_message = "Allowed methods must be one or more of: GET, PUT, POST, DELETE, HEAD."
  }
}

# Website Hosting Configuration
variable "enable_website_hosting" {
  description = "Enable static website hosting"
  type        = bool
  default     = false
}

variable "website_index_document" {
  description = "Index document for website hosting (e.g., index.html)"
  type        = string
  default     = null
}

variable "website_error_document" {
  description = "Error document for website hosting (e.g., error.html)"
  type        = string
  default     = null
}

variable "website_routing_rules" {
  description = "Website routing rules"
  type = list(object({
    condition = object({
      http_error_code_returned_equals = optional(string)
      key_prefix_equals               = optional(string)
    })
    redirect = object({
      host_name               = optional(string)
      http_redirect_code      = optional(string)
      protocol                = optional(string)
      replace_key_prefix_with = optional(string)
      replace_key_with        = optional(string)
    })
  }))
  default = []
}

# Object Lock Configuration
variable "enable_object_lock" {
  description = "Enable object lock (requires versioning). WARNING: Cannot be disabled once enabled."
  type        = bool
  default     = false
}

variable "object_lock_retention" {
  description = <<-EOT
    Default retention settings for object lock:
    - mode: Retention mode (GOVERNANCE or COMPLIANCE)
    - days: Retention period in days (use days OR years, not both)
    - years: Retention period in years (use days OR years, not both)
  EOT
  type = object({
    mode  = string
    days  = optional(number)
    years = optional(number)
  })
  default = null

  validation {
    condition = var.object_lock_retention == null || (
      contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_retention.mode) &&
      (
        (var.object_lock_retention.days != null && var.object_lock_retention.years == null) ||
        (var.object_lock_retention.days == null && var.object_lock_retention.years != null)
      )
    )
    error_message = "Object lock retention mode must be GOVERNANCE or COMPLIANCE, and must specify either days OR years (not both)."
  }
}

# Replication Configuration
# Note: Replication is handled by the s3-crr module
# See: ../s3-crr for cross-region replication configuration

# Notification Configuration
# Note: Bucket notifications can be configured separately if needed using aws_s3_bucket_notification resource
