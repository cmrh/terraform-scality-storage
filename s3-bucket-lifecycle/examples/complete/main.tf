# Complete Lifecycle Example
# This example demonstrates all supported lifecycle features

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

# Create versioned S3 bucket
resource "aws_s3_bucket" "complete" {
  bucket = var.bucket_name

  tags = merge(
    var.tags,
    {
      Name        = var.bucket_name
      Environment = "Example"
      Purpose     = "Complete-Lifecycle-Demo"
      ManagedBy   = "OpenTofu"
    }
  )
}

# Enable versioning
resource "aws_s3_bucket_versioning" "complete" {
  bucket = aws_s3_bucket.complete.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Comprehensive lifecycle configuration
module "lifecycle" {
  source = "../../"

  bucket_name       = aws_s3_bucket.complete.id
  bucket_dependency = aws_s3_bucket_versioning.complete

  lifecycle_rules = [
    # Expiration by days
    {
      id      = "expire-by-days"
      enabled = true
      filter = {
        prefix = "data/"
      }
      expiration = {
        days = 365
      }
    },

    # Expiration by date (example: cleanup old test data)
    {
      id      = "expire-by-date"
      enabled = var.enable_date_expiration
      filter = {
        prefix = "test-data/"
      }
      expiration = {
        date = "2026-12-31T00:00:00Z"
      }
    },

    # Noncurrent version expiration
    {
      id      = "expire-old-versions"
      enabled = true
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    },

    # Delete expired object delete markers
    {
      id      = "cleanup-delete-markers"
      enabled = true
      expiration = {
        expired_object_delete_marker = true
      }
    },

    # Tag-based expiration
    {
      id      = "expire-tagged-temp"
      enabled = true
      filter = {
        tag = {
          key   = "Lifecycle"
          value = "Temporary"
        }
      }
      expiration = {
        days = 7
      }
    },

    # Combined filter: prefix + multiple tags
    {
      id      = "expire-dev-logs"
      enabled = true
      filter = {
        and = {
          prefix = "logs/"
          tags = {
            Environment = "development"
            Type        = "log"
          }
        }
      }
      expiration = {
        days = 14
      }
    },

    # Production logs (longer retention)
    {
      id      = "expire-prod-logs"
      enabled = true
      filter = {
        and = {
          prefix = "logs/"
          tags = {
            Environment = "production"
          }
        }
      }
      expiration = {
        days = 90
      }
    },

    # Abort incomplete multipart uploads
    {
      id      = "abort-multipart"
      enabled = true
      abort_incomplete_multipart_upload = {
        days_after_initiation = var.multipart_abort_days
      }
    },

    # Short-lived cache objects
    {
      id      = "expire-cache"
      enabled = true
      filter = {
        prefix = "cache/"
      }
      expiration = {
        days = 1
      }
    }
  ]

  tags = var.tags
}

# Outputs
output "bucket_id" {
  description = "ID of the created bucket"
  value       = aws_s3_bucket.complete.id
}

output "bucket_arn" {
  description = "ARN of the created bucket"
  value       = aws_s3_bucket.complete.arn
}

output "versioning_enabled" {
  description = "Whether versioning is enabled"
  value       = aws_s3_bucket_versioning.complete.versioning_configuration[0].status == "Enabled"
}

output "lifecycle_configuration_id" {
  description = "ID of the lifecycle configuration"
  value       = module.lifecycle.lifecycle_configuration_id
}

output "total_rules" {
  description = "Total number of lifecycle rules configured"
  value       = module.lifecycle.rule_count
}

output "enabled_rules" {
  description = "List of enabled rule IDs"
  value       = module.lifecycle.enabled_rules
}

output "all_rules" {
  description = "Complete lifecycle rules configuration"
  value       = module.lifecycle.lifecycle_rules
}
