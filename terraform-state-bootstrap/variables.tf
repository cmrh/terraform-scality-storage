variable "scality_endpoint" {
  description = "Scality S3 endpoint URL (e.g., http://10.164.169.247)"
  type        = string
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "terraform-state"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.state_bucket_name))
    error_message = "Bucket name must be lowercase alphanumeric with hyphens, starting and ending with alphanumeric characters."
  }
}

variable "use_https" {
  description = "Use HTTPS for connections to Scality endpoint"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable server-side encryption on the state bucket (if supported by Scality)"
  type        = bool
  default     = false
}

variable "enable_lifecycle_rules" {
  description = "Enable lifecycle rules to delete old state versions"
  type        = bool
  default     = true
}

variable "old_version_retention_days" {
  description = "Number of days to retain old state file versions"
  type        = number
  default     = 90

  validation {
    condition     = var.old_version_retention_days >= 1
    error_message = "Retention days must be at least 1."
  }
}

variable "state_directories" {
  description = "List of directories to create in the state bucket for organization"
  type        = list(string)
  default = [
    "bootstrap",
    "account-management",
    "infrastructure",
    "applications",
  ]
}

variable "directory_descriptions" {
  description = "Descriptions for state directories"
  type        = map(string)
  default = {
    "bootstrap"          = "Bootstrap state (this module)"
    "account-management" = "Scality account and IAM management"
    "infrastructure"     = "Core infrastructure resources"
    "applications"       = "Application deployments"
  }
}

variable "tags" {
  description = "Additional tags to apply to the state bucket"
  type        = map(string)
  default     = {}
}
