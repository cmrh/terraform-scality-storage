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
  default     = "lifecycle-multi-rule-example"
}
