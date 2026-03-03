variable "source_bucket_name" {
  description = "Name of the source S3 bucket"
  type        = string
  default     = "my-source-bucket"
}

variable "destination_bucket_name" {
  description = "Name of the destination S3 bucket"
  type        = string
  default     = "my-destination-bucket"
}

variable "source_endpoint" {
  description = "S3 endpoint URL for source"
  type        = string
  default     = "https://source.scality.local"
}

variable "destination_endpoint" {
  description = "S3 endpoint URL for destination"
  type        = string
  default     = "https://destination.scality.local"
}

variable "source_region" {
  description = "AWS region for source"
  type        = string
  default     = "us-east-1"
}

variable "destination_region" {
  description = "AWS region for destination"
  type        = string
  default     = "us-west-2"
}

variable "source_access_key" {
  description = "AWS access key for source"
  type        = string
  sensitive   = true
}

variable "source_secret_key" {
  description = "AWS secret key for source"
  type        = string
  sensitive   = true
}

variable "destination_access_key" {
  description = "AWS access key for destination"
  type        = string
  sensitive   = true
}

variable "destination_secret_key" {
  description = "AWS secret key for destination"
  type        = string
  sensitive   = true
}

variable "create_source_bucket" {
  description = "Whether to create the source bucket"
  type        = bool
  default     = true
}

variable "create_destination_bucket" {
  description = "Whether to create the destination bucket"
  type        = bool
  default     = true
}

variable "policy_name" {
  description = "Custom policy name (optional)"
  type        = string
  default     = ""
}

variable "role_name" {
  description = "Custom role name (optional)"
  type        = string
  default     = ""
}

variable "replication_prefix" {
  description = "Prefix for objects to replicate"
  type        = string
  default     = ""
}

variable "replication_status" {
  description = "Replication status (Enabled or Disabled)"
  type        = string
  default     = "Enabled"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "development"
    ManagedBy   = "Terraform"
    Purpose     = "CRR-Example"
  }
}
