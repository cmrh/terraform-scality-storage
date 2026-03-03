# Versioned Bucket Lifecycle Example
# This example shows lifecycle rules for managing versioned buckets

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Configure AWS provider for Scality
provider "aws" {
  region = var.region

  endpoints {
    s3 = var.s3_endpoint
  }

  access_key = var.access_key
  secret_key = var.secret_key

  # Scality-specific settings
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}

# Create S3 bucket
resource "aws_s3_bucket" "versioned" {
  bucket = var.bucket_name

  tags = {
    Environment = "Example"
    Purpose     = "Versioned-Lifecycle-Demo"
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "versioned" {
  bucket = aws_s3_bucket.versioned.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Configure lifecycle rules for versioned bucket
module "lifecycle" {
  source = "../../"

  bucket_name       = aws_s3_bucket.versioned.id
  bucket_dependency = aws_s3_bucket_versioning.versioned

  lifecycle_rules = [
    # Delete current versions after 365 days
    {
      id      = "expire-current-versions"
      enabled = true
      expiration = {
        days = 365
      }
    },

    # Delete noncurrent versions after 90 days
    {
      id      = "expire-noncurrent-versions"
      enabled = true
      noncurrent_version_expiration = {
        noncurrent_days = 90
      }
    },

    # Remove expired object delete markers
    {
      id      = "remove-delete-markers"
      enabled = true
      expiration = {
        expired_object_delete_marker = true
      }
    },

    # Abort incomplete multipart uploads
    {
      id      = "abort-multipart"
      enabled = true
      abort_incomplete_multipart_upload = {
        days_after_initiation = 7
      }
    }
  ]
}

# Outputs
output "bucket_name" {
  description = "Name of the versioned bucket"
  value       = module.lifecycle.bucket_name
}

output "versioning_status" {
  description = "Versioning configuration"
  value       = aws_s3_bucket_versioning.versioned.versioning_configuration
}

output "lifecycle_rules" {
  description = "Applied lifecycle rules"
  value       = module.lifecycle.lifecycle_rules
}
