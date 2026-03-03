# Basic S3 Bucket Lifecycle Example
# This example shows simple expiration rules for log cleanup

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

# Create S3 bucket (or use existing)
resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name

  tags = {
    Environment = "Example"
    Purpose     = "Lifecycle-Demo"
  }
}

# Configure lifecycle rules
module "lifecycle" {
  source = "../../"

  bucket_name       = aws_s3_bucket.example.id
  bucket_dependency = aws_s3_bucket.example

  lifecycle_rules = [
    # Delete logs after 90 days
    {
      id      = "expire-logs"
      enabled = true
      filter = {
        prefix = "logs/"
      }
      expiration = {
        days = 90
      }
    },

    # Abort incomplete multipart uploads after 7 days
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
  description = "Name of the created bucket"
  value       = module.lifecycle.bucket_name
}

output "lifecycle_rules" {
  description = "Applied lifecycle rules"
  value       = module.lifecycle.lifecycle_rules
}

output "enabled_rules" {
  description = "Enabled rule IDs"
  value       = module.lifecycle.enabled_rules
}
