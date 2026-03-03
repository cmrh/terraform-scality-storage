terraform {
  required_version = ">= 1.0"
}

# Simple example with one user and one policy
module "scality_iam" {
  source = "../.."

  scality_endpoint = "http://10.164.169.247"

  # Credentials from environment variables:
  # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

  # Create a simple read-only policy
  policies = {
    s3_read_only = {
      description = "Read-only access to S3 buckets"
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

  # Create a user with the policy
  users = {
    readonly_user = {
      policies = ["s3_read_only"]
      tags = {
        Purpose = "Read-only access"
      }
      generate_access_key = true
    }
  }
}

# Output the user credentials
output "user_credentials" {
  description = "Access credentials for readonly_user"
  value = {
    access_key = module.scality_iam.user_access_keys["readonly_user"].access_key
    secret_key = module.scality_iam.user_access_keys["readonly_user"].secret_key
  }
  sensitive = true
}

output "usage_instructions" {
  value = <<-EOT
    User created successfully!

    To use these credentials with AWS CLI:

    export AWS_ACCESS_KEY_ID=$(terraform output -json user_credentials | jq -r '.access_key')
    export AWS_SECRET_ACCESS_KEY=$(terraform output -json user_credentials | jq -r '.secret_key')
    aws s3 ls --endpoint-url http://10.164.169.247

    Or view credentials:
    terraform output -json user_credentials | jq
  EOT
}
