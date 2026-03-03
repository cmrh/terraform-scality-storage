# Multi-Rule Lifecycle Example
# This example shows multiple lifecycle rules with different filters

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
resource "aws_s3_bucket" "multi" {
  bucket = var.bucket_name

  tags = {
    Environment = "Example"
    Purpose     = "Multi-Rule-Lifecycle-Demo"
  }
}

# Configure multiple lifecycle rules with different filters
module "lifecycle" {
  source = "../../"

  bucket_name       = aws_s3_bucket.multi.id
  bucket_dependency = aws_s3_bucket.multi

  lifecycle_rules = [
    # Rule 1: Delete logs after 30 days
    {
      id      = "expire-logs"
      enabled = true
      filter = {
        prefix = "logs/"
      }
      expiration = {
        days = 30
      }
    },

    # Rule 2: Delete temporary files after 7 days (tag-based)
    {
      id      = "expire-temp-files"
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

    # Rule 3: Delete dev environment backups after 14 days (prefix + tags)
    {
      id      = "expire-dev-backups"
      enabled = true
      filter = {
        and = {
          prefix = "backups/"
          tags = {
            Environment = "dev"
            Type        = "backup"
          }
        }
      }
      expiration = {
        days = 14
      }
    },

    # Rule 4: Keep production backups for 90 days
    {
      id      = "expire-prod-backups"
      enabled = true
      filter = {
        and = {
          prefix = "backups/"
          tags = {
            Environment = "production"
          }
        }
      }
      expiration = {
        days = 90
      }
    },

    # Rule 5: Abort incomplete multipart uploads
    {
      id      = "abort-multipart"
      enabled = true
      abort_incomplete_multipart_upload = {
        days_after_initiation = 3
      }
    },

    # Rule 6: Archive cleanup (can be disabled)
    {
      id      = "expire-archives"
      enabled = false
      filter = {
        prefix = "archive/"
      }
      expiration = {
        days = 180
      }
    }
  ]
}

# Outputs
output "bucket_name" {
  description = "Name of the bucket"
  value       = module.lifecycle.bucket_name
}

output "total_rules" {
  description = "Total number of lifecycle rules"
  value       = module.lifecycle.rule_count
}

output "enabled_rules" {
  description = "List of enabled rule IDs"
  value       = module.lifecycle.enabled_rules
}
