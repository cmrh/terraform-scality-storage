variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "s3_endpoint" {
  description = "Scality S3 endpoint URL"
  type        = string
}

variable "access_key" {
  description = "Scality access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Scality secret key"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "lifecycle-complete-example"
}

variable "enable_date_expiration" {
  description = "Whether to enable date-based expiration rule"
  type        = bool
  default     = false
}

variable "multipart_abort_days" {
  description = "Days after which to abort incomplete multipart uploads"
  type        = number
  default     = 7

  validation {
    condition     = var.multipart_abort_days > 0 && var.multipart_abort_days <= 365
    error_message = "Multipart abort days must be between 1 and 365."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project   = "S3-Lifecycle"
    Terraform = "true"
    Example   = "complete"
  }
}
