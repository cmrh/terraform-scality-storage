terraform {
  required_version = ">= 1.0"

  required_providers {
    scality = {
      source = "scality/scality"
    }
  }
}

# Configure Scality provider for account creation
provider "scality" {
  console_endpoint = var.console_endpoint
  console_username = var.console_username
  console_password = var.console_password
}

# Create a Scality account using Console API
resource "scality_console_account" "app" {
  account_name = "my-application"
  email        = "app@example.com"
  quota        = 100000000000  # 100GB
}

# Use the account credentials to manage IAM resources
module "app_iam" {
  source = "../.."

  scality_endpoint = var.scality_endpoint

  # Use credentials from the created account
  access_key = scality_console_account.app.access_key
  secret_key = scality_console_account.app.secret_key

  # Define policies for different access levels
  policies = {
    app_full_access = {
      description = "Full S3 access for application"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "s3:*"
          Resource = "*"
        }]
      })
    }

    app_read_only = {
      description = "Read-only S3 access"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = "*"
        }]
      })
    }
  }

  # Create groups for different roles
  groups = {
    app_admins = {
      policies = ["app_full_access"]
    }
    app_readers = {
      policies = ["app_read_only"]
    }
  }

  # Create users
  users = {
    app_admin = {
      groups = ["app_admins"]
      tags = {
        Role        = "Administrator"
        Application = "MyApp"
      }
    }

    app_service = {
      groups = ["app_readers"]
      tags = {
        Role        = "Service"
        Application = "MyApp"
      }
    }
  }
}

# Save credentials to files
resource "local_file" "account_credentials" {
  content = <<-EOT
    # Scality Account Admin Credentials
    # Account: ${scality_console_account.app.account_name}

    [account_admin]
    aws_access_key_id = ${scality_console_account.app.access_key}
    aws_secret_access_key = ${scality_console_account.app.secret_key}

    # Created: ${scality_console_account.app.created_at}
    # Quota: ${scality_console_account.app.quota} bytes
  EOT

  filename        = "${path.module}/credentials/account_admin.ini"
  file_permission = "0600"
}

resource "local_file" "user_credentials" {
  for_each = module.app_iam.user_access_keys

  content = <<-EOT
    # Scality User Credentials
    # User: ${each.key}
    # Account: ${scality_console_account.app.account_name}

    [${each.key}]
    aws_access_key_id = ${each.value.access_key}
    aws_secret_access_key = ${each.value.secret_key}

    # Usage:
    # aws s3 ls --profile ${each.key} --endpoint-url ${var.scality_endpoint}
  EOT

  filename        = "${path.module}/credentials/${each.key}.ini"
  file_permission = "0600"
}

# Outputs
output "account_info" {
  description = "Scality account information"
  value = {
    account_name = scality_console_account.app.account_name
    email        = scality_console_account.app.email
    quota        = scality_console_account.app.quota
    created_at   = scality_console_account.app.created_at
  }
}

output "iam_summary" {
  description = "Summary of IAM resources created"
  value       = module.app_iam.summary
}

output "account_admin_credentials" {
  description = "Account administrator credentials (sensitive)"
  value = {
    access_key = scality_console_account.app.access_key
    secret_key = scality_console_account.app.secret_key
  }
  sensitive = true
}

output "user_credentials" {
  description = "IAM user credentials (sensitive)"
  value       = module.app_iam.user_access_keys
  sensitive   = true
}

output "credentials_location" {
  description = "Location of saved credential files"
  value = {
    account_admin = "${path.module}/credentials/account_admin.ini"
    users = {
      for user in keys(module.app_iam.user_access_keys) :
      user => "${path.module}/credentials/${user}.ini"
    }
  }
}
