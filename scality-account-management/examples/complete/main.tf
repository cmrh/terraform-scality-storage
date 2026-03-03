terraform {
  required_version = ">= 1.0"
}

# Use the Scality account management module
module "scality_iam" {
  source = "../.."

  scality_endpoint = var.scality_endpoint
  use_https        = var.use_https

  # Credentials will be picked up from AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables
  # Or you can pass them explicitly:
  # access_key = var.access_key
  # secret_key = var.secret_key

  # Define IAM policies
  policies = {
    s3_read_only = {
      description = "Read-only access to S3 buckets"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:GetObjectVersion",
              "s3:ListBucket",
              "s3:ListBucketVersions"
            ]
            Resource = "*"
          }
        ]
      })
    }

    s3_full_access = {
      description = "Full access to S3 buckets"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect   = "Allow"
            Action   = "s3:*"
            Resource = "*"
          }
        ]
      })
    }

    s3_bucket_specific = {
      description = "Access to specific bucket"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "arn:aws:s3:::my-app-bucket/*"
          },
          {
            Effect = "Allow"
            Action = [
              "s3:ListBucket"
            ]
            Resource = "arn:aws:s3:::my-app-bucket"
          }
        ]
      })
    }
  }

  # Define IAM groups
  groups = {
    developers = {
      path     = "/teams/"
      policies = ["s3_read_only"]
    }

    admins = {
      path     = "/teams/"
      policies = ["s3_full_access"]
    }

    app_users = {
      path     = "/apps/"
      policies = ["s3_bucket_specific"]
    }
  }

  # Define IAM users
  users = {
    alice = {
      path   = "/teams/"
      groups = ["developers"]
      tags = {
        Team = "Development"
        Role = "Developer"
      }
      generate_access_key = true
    }

    bob = {
      path   = "/teams/"
      groups = ["admins"]
      tags = {
        Team = "Operations"
        Role = "Admin"
      }
      generate_access_key = true
    }

    app_service = {
      path     = "/apps/"
      groups   = ["app_users"]
      policies = []  # Gets permissions from group
      tags = {
        Application = "MyApp"
        Environment = "Production"
      }
      generate_access_key = true
    }

    backup_user = {
      path     = "/"
      groups   = []
      policies = ["s3_full_access"]  # Direct policy attachment
      tags = {
        Purpose = "Backup"
      }
      generate_access_key = true
    }
  }
}

# Save user credentials to files
resource "local_file" "user_credentials" {
  for_each = module.scality_iam.user_access_keys

  content = <<-EOT
    # Scality S3 Credentials for ${each.key}
    # Generated: ${timestamp()}

    [${each.key}]
    aws_access_key_id = ${each.value.access_key}
    aws_secret_access_key = ${each.value.secret_key}

    # Usage with AWS CLI:
    # aws s3 ls --profile ${each.key} --endpoint-url ${var.scality_endpoint}

    # Export as environment variables:
    # export AWS_ACCESS_KEY_ID=${each.value.access_key}
    # export AWS_SECRET_ACCESS_KEY=${each.value.secret_key}
    # export AWS_ENDPOINT_URL=${var.scality_endpoint}
  EOT

  filename        = "${path.module}/credentials/${each.key}.ini"
  file_permission = "0600"
}
