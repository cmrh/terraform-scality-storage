variable "source_bucket_name" {
  description = "Name of the source S3 bucket"
  type        = string
}

variable "destination_bucket_name" {
  description = "Name of the destination S3 bucket"
  type        = string
}

variable "source_endpoint" {
  description = "S3 endpoint URL for source (e.g., https://source.scality.com)"
  type        = string
}

variable "destination_endpoint" {
  description = "S3 endpoint URL for destination (e.g., https://dest.scality.com)"
  type        = string
}

variable "source_region" {
  description = "AWS region for source bucket"
  type        = string
  default     = "us-east-1"
}

variable "destination_region" {
  description = "AWS region for destination bucket"
  type        = string
  default     = "us-east-1"
}

variable "source_access_key" {
  description = "Access key for source. Can be omitted if using environment variable SCALITY_SOURCE_ACCESS_KEY"
  type        = string
  sensitive   = true
  default     = null
}

variable "source_secret_key" {
  description = "Secret key for source. Can be omitted if using environment variable SCALITY_SOURCE_SECRET_KEY"
  type        = string
  sensitive   = true
  default     = null
}

variable "destination_access_key" {
  description = "Access key for destination. Can be omitted if using environment variable SCALITY_DESTINATION_ACCESS_KEY"
  type        = string
  sensitive   = true
  default     = null
}

variable "destination_secret_key" {
  description = "Secret key for destination. Can be omitted if using environment variable SCALITY_DESTINATION_SECRET_KEY"
  type        = string
  sensitive   = true
  default     = null
}

variable "create_source_bucket" {
  description = "Whether to create the source bucket if it doesn't exist"
  type        = bool
  default     = false
}

variable "create_destination_bucket" {
  description = "Whether to create the destination bucket if it doesn't exist"
  type        = bool
  default     = false
}

variable "policy_name" {
  description = "Name for the IAM policy (will append timestamp if not unique)"
  type        = string
  default     = ""
}

variable "role_name" {
  description = "Name for the IAM trust role (will append timestamp if not unique)"
  type        = string
  default     = ""
}

variable "replication_prefix" {
  description = "Prefix for objects to replicate (empty string means all objects)"
  type        = string
  default     = ""
}

variable "replication_status" {
  description = "Status of the replication rule (Enabled or Disabled)"
  type        = string
  default     = "Enabled"

  validation {
    condition     = contains(["Enabled", "Disabled"], var.replication_status)
    error_message = "Replication status must be either 'Enabled' or 'Disabled'."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "skip_credentials_validation" {
  description = "Skip validation of credentials against STS (useful for Scality)"
  type        = bool
  default     = true
}

variable "skip_metadata_api_check" {
  description = "Skip metadata API check (useful for Scality)"
  type        = bool
  default     = true
}

variable "skip_requesting_account_id" {
  description = "Skip requesting account ID (useful for Scality)"
  type        = bool
  default     = false
}

variable "force_path_style" {
  description = "Force S3 path style (bucket.s3.amazonaws.com vs s3.amazonaws.com/bucket)"
  type        = bool
  default     = true
}

variable "assume_role_principal" {
  description = "Service principal for assume role policy (default: backbeat for Scality)"
  type        = string
  default     = "backbeat"
}

variable "source_account_id" {
  description = "Source account ID (if not auto-detected via STS)"
  type        = string
  default     = ""
}

variable "destination_account_id" {
  description = "Destination account ID (if not auto-detected via STS)"
  type        = string
  default     = ""
}
