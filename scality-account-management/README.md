# Scality Account Management Module

Manage IAM users, groups, and policies within Scality accounts using Terraform.

## Features

- IAM user creation with automatic access key generation
- IAM groups and policies
- User-to-group and policy attachments
- Environment variable credential support
- Tagging

## Prerequisites

- Terraform >= 1.0
- AWS provider >= 5.0
- Scality account admin credentials

## Quick Start

**Set credentials via environment variables** (recommended):

```bash
export AWS_ACCESS_KEY_ID="account-admin-access-key"
export AWS_SECRET_ACCESS_KEY="account-admin-secret-key"
```

**Basic usage:**

```hcl
module "scality_iam" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//scality-account-management"

  scality_endpoint = "http://scality.example.com"

  users = {
    developer = {
      groups = ["developers"]
      generate_access_key = true
    }
  }

  groups = {
    developers = {
      policies = ["s3_read_only"]
    }
  }

  policies = {
    s3_read_only = {
      description = "Read-only S3 access"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:ListBucket"]
          Resource = "*"
        }]
      })
    }
  }
}
```

## Integration with Scality Provider

```hcl
# Create account
resource "scality_console_account" "app" {
  account_name = "my-app"
  email        = "app@example.com"
  quota        = 107374182400  # 100GB
}

# Manage IAM within that account
module "app_iam" {
  source = "../scality-account-management"

  scality_endpoint = var.scality_endpoint
  access_key       = scality_console_account.app.access_key
  secret_key       = scality_console_account.app.secret_key

  users = {
    app_user = {
      policies = ["s3_full_access"]
    }
  }

  policies = {
    s3_full_access = {
      description = "Full S3 access"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "s3:*"
          Resource = "*"
        }]
      })
    }
  }
}

output "app_user_credentials" {
  value = {
    access_key = module.app_iam.user_access_keys["app_user"].access_key
    secret_key = module.app_iam.user_access_keys["app_user"].secret_key
  }
  sensitive = true
}
```

## Module Structure

```
scality-account-management/
├── main.tf           # Main module logic
├── variables.tf      # Module input variables
├── outputs.tf        # Module outputs
├── users/            # Users submodule
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── groups/           # Groups submodule
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── policies/         # Policies submodule
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── examples/         # Usage examples
    └── complete/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `scality_endpoint` | Scality S3/IAM endpoint URL | `string` | n/a | yes |
| `access_key` | Account admin access key | `string` | `null` | no* |
| `secret_key` | Account admin secret key | `string` | `null` | no* |
| `use_https` | Use HTTPS for connections | `bool` | `false` | no |
| `users` | Map of IAM users to create | `map(object)` | `{}` | no |
| `groups` | Map of IAM groups to create | `map(object)` | `{}` | no |
| `policies` | Map of IAM policies to create | `map(object)` | `{}` | no |

*Uses `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables if not provided

### User Object Schema

```hcl
{
  path                = optional(string, "/")
  tags                = optional(map(string), {})
  groups              = optional(list(string), [])
  policies            = optional(list(string), [])
  generate_access_key = optional(bool, true)
}
```

### Group Object Schema

```hcl
{
  path     = optional(string, "/")
  policies = optional(list(string), [])
}
```

### Policy Object Schema

```hcl
{
  description     = string
  policy_document = string
  path            = optional(string, "/")
}
```

## Outputs

| Name | Description | Sensitive |
|------|-------------|-----------|
| `users` | Map of created IAM users | No |
| `user_access_keys` | Map of user access keys | Yes |
| `groups` | Map of created IAM groups | No |
| `policies` | Map of created IAM policies | No |
| `policy_arns` | Map of policy names to ARNs | No |
| `user_group_memberships` | List of user-to-group memberships | No |
| `summary` | Summary of created resources | No |

## Examples

### Complete Example

See [examples/complete](examples/complete/) for a comprehensive example with:
- Multiple policies (read-only, full access, bucket-specific)
- Multiple groups (developers, admins, app_users)
- Multiple users with different permissions
- Credential file generation

Run the example:
```bash
cd examples/complete

# Set account admin credentials
export AWS_ACCESS_KEY_ID="your-account-admin-access-key"
export AWS_SECRET_ACCESS_KEY="your-account-admin-secret-key"

# Initialize and apply
terraform init
terraform apply

# View created resources
terraform output summary

# View user credentials (sensitive)
terraform output -json user_credentials | jq
```

### Policy Examples

#### S3 Read-Only Access

```hcl
policies = {
  s3_read_only = {
    description = "Read-only access to S3"
    policy_document = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ]
        Resource = "*"
      }]
    })
  }
}
```

#### Bucket-Specific Access

```hcl
policies = {
  app_bucket_access = {
    description = "Access to specific bucket"
    policy_document = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
          Resource = "arn:aws:s3:::my-app-bucket/*"
        },
        {
          Effect = "Allow"
          Action = ["s3:ListBucket"]
          Resource = "arn:aws:s3:::my-app-bucket"
        }
      ]
    })
  }
}
```

#### Full S3 Access

```hcl
policies = {
  s3_admin = {
    description = "Full S3 administrative access"
    policy_document = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "s3:*"
        Resource = "*"
      }]
    })
  }
}
```

### Advanced Scenarios

#### Multi-Tier Access Control

```hcl
module "scality_iam" {
  source = "path/to/scality-account-management"

  scality_endpoint = var.scality_endpoint

  # Define tiered policies
  policies = {
    tier1_read = {
      description = "Tier 1 - Read only"
      policy_document = file("policies/tier1_read.json")
    }
    tier2_write = {
      description = "Tier 2 - Read and write"
      policy_document = file("policies/tier2_write.json")
    }
    tier3_admin = {
      description = "Tier 3 - Full access"
      policy_document = file("policies/tier3_admin.json")
    }
  }

  # Create groups for each tier
  groups = {
    tier1 = { policies = ["tier1_read"] }
    tier2 = { policies = ["tier2_write"] }
    tier3 = { policies = ["tier3_admin"] }
  }

  # Assign users to tiers
  users = {
    junior_dev  = { groups = ["tier1"] }
    senior_dev  = { groups = ["tier2"] }
    team_lead   = { groups = ["tier3"] }
  }
}
```

#### Application Service Accounts

```hcl
module "app_services" {
  source = "path/to/scality-account-management"

  scality_endpoint = var.scality_endpoint

  policies = {
    app1_policy = {
      description = "App1 bucket access"
      policy_document = templatefile("policies/app_bucket.json", {
        bucket_name = "app1-data"
      })
    }
    app2_policy = {
      description = "App2 bucket access"
      policy_document = templatefile("policies/app_bucket.json", {
        bucket_name = "app2-data"
      })
    }
  }

  users = {
    app1_service = {
      path     = "/services/"
      policies = ["app1_policy"]
      tags     = { Application = "App1", Environment = "Production" }
    }
    app2_service = {
      path     = "/services/"
      policies = ["app2_policy"]
      tags     = { Application = "App2", Environment = "Production" }
    }
  }
}
```

## Credential Management

### Using Environment Variables (Recommended)

```bash
# From Scality provider output
export AWS_ACCESS_KEY_ID=$(terraform output -json scality_account | jq -r '.access_key')
export AWS_SECRET_ACCESS_KEY=$(terraform output -json scality_account | jq -r '.secret_key')

terraform apply
```

### Using Variables

```hcl
module "scality_iam" {
  source = "path/to/scality-account-management"

  scality_endpoint = var.scality_endpoint
  access_key       = var.account_admin_access_key
  secret_key       = var.account_admin_secret_key

  # ... rest of configuration
}
```

### Retrieving User Credentials

```bash
# View all user credentials
terraform output -json user_credentials | jq

# Get specific user credentials
terraform output -json user_credentials | jq '.app_user'

# Export for use with AWS CLI
export AWS_ACCESS_KEY_ID=$(terraform output -json user_credentials | jq -r '.app_user.access_key')
export AWS_SECRET_ACCESS_KEY=$(terraform output -json user_credentials | jq -r '.app_user.secret_key')

# Test with AWS CLI
aws s3 ls --endpoint-url http://10.164.169.247
```

## Security Best Practices

1. **Protect Admin Credentials**
   ```bash
   # Use environment variables
   export AWS_ACCESS_KEY_ID="admin-key"
   export AWS_SECRET_ACCESS_KEY="admin-secret"

   # Don't commit to version control
   echo ".env" >> .gitignore
   echo "terraform.tfstate*" >> .gitignore
   ```

2. **Use Remote State with Encryption**
   ```hcl
   terraform {
     backend "s3" {
       bucket  = "terraform-state"
       key     = "scality-iam/terraform.tfstate"
       encrypt = true
     }
   }
   ```

3. **Mark Sensitive Outputs**
   ```hcl
   output "user_keys" {
     value     = module.scality_iam.user_access_keys
     sensitive = true
   }
   ```

4. **Use Least Privilege Policies**
   - Grant minimum permissions required
   - Use bucket-specific policies instead of wildcard
   - Regularly audit user permissions

5. **Rotate Credentials**
   ```bash
   # Force credential rotation
   terraform taint 'module.scality_iam.module.users.aws_iam_access_key.user_keys["username"]'
   terraform apply
   ```

## Troubleshooting

### Authentication Failures

**Error**: `Error: error configuring Terraform AWS Provider: no valid credential sources found`

**Solution**: Set environment variables or provide credentials explicitly:
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

### Endpoint Connection Issues

**Error**: `dial tcp: lookup ... no such host`

**Solution**: Verify endpoint URL is correct and accessible:
```bash
curl http://10.164.169.247
```

### Policy Syntax Errors

**Error**: `MalformedPolicyDocument`

**Solution**: Validate JSON policy document:
```bash
echo '$POLICY' | jq .
```

### User Already Exists

**Error**: `EntityAlreadyExists: User with name ... already exists`

**Solution**: Import existing user or use different name:
```bash
terraform import 'module.scality_iam.module.users.aws_iam_user.users["username"]' username
```

## Limitations

- AWS provider limitations apply (some IAM features may not be supported by Scality)
- Access keys cannot be retrieved after creation (store outputs securely)
- Policy updates may require resource replacement
- Limited to IAM features supported by Scality S3

## Contributing

Contributions are welcome! Please ensure:
- Code follows Terraform best practices
- Examples are tested
- Documentation is updated
- Variables have descriptions

## License

This module is provided as-is for use with Scality storage systems.

## See Also

- [Scality Provider](../../Providers/terraform-provider-scality/) - For creating Scality accounts
- [AWS IAM Documentation](https://docs.aws.amazon.com/IAM/latest/UserGuide/) - For policy syntax and concepts
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) - For AWS provider reference
