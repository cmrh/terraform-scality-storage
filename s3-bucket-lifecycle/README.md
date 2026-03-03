# S3 Bucket Lifecycle Configuration Module

Terraform/OpenTofu module for managing S3 bucket lifecycle policies on Scality systems.

## Features

- **Expiration Rules**: Automatically delete objects after a specified number of days or on a specific date
- **Noncurrent Version Expiration**: Clean up old object versions in versioned buckets
- **Abort Incomplete Multipart Uploads**: Automatically abort incomplete multipart uploads after a specified period
- **Flexible Filtering**: Filter objects by prefix, tags, or combinations
- **Multiple Rules**: Support for multiple lifecycle rules on a single bucket

## Important Limitations

**Transition policies are NOT supported** by Scality. This module only supports:
- `put_bucket_lifecycle` - Create/update lifecycle configuration
- `get_bucket_lifecycle` - Read lifecycle configuration
- `delete_bucket_lifecycle` - Remove lifecycle configuration

Transition actions (e.g., moving objects between storage classes) are not available.

## Usage

### Basic Example - Simple Expiration

```hcl
module "lifecycle" {
  source = "../s3-bucket-lifecycle"

  bucket_name = "my-bucket"

  lifecycle_rules = [
    {
      id      = "expire-old-logs"
      enabled = true
      filter = {
        prefix = "logs/"
      }
      expiration = {
        days = 90
      }
    }
  ]
}
```

### Example - Multiple Rules

```hcl
module "lifecycle" {
  source = "../s3-bucket-lifecycle"

  bucket_name = "my-versioned-bucket"

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
      id      = "expire-old-versions"
      enabled = true
      noncurrent_version_expiration = {
        noncurrent_days = 90
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
```

### Example - Tag-Based Filtering

```hcl
module "lifecycle" {
  source = "../s3-bucket-lifecycle"

  bucket_name = "my-bucket"

  lifecycle_rules = [
    {
      id      = "expire-temp-files"
      enabled = true
      filter = {
        tag = {
          key   = "Type"
          value = "Temporary"
        }
      }
      expiration = {
        days = 30
      }
    }
  ]
}
```

### Example - Combined Prefix and Tag Filtering

```hcl
module "lifecycle" {
  source = "../s3-bucket-lifecycle"

  bucket_name = "my-bucket"

  lifecycle_rules = [
    {
      id      = "expire-old-temp-logs"
      enabled = true
      filter = {
        and = {
          prefix = "logs/"
          tags = {
            Environment = "dev"
            Type        = "temporary"
          }
        }
      }
      expiration = {
        days = 14
      }
    }
  ]
}
```

### Example - Delete Expired Object Delete Markers

```hcl
module "lifecycle" {
  source = "../s3-bucket-lifecycle"

  bucket_name = "my-versioned-bucket"

  lifecycle_rules = [
    {
      id      = "remove-delete-markers"
      enabled = true
      expiration = {
        expired_object_delete_marker = true
      }
    }
  ]
}
```

### Example - With Bucket Creation

```hcl
# Create bucket
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}

# Enable versioning (required for noncurrent version expiration)
resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Configure lifecycle
module "lifecycle" {
  source = "../s3-bucket-lifecycle"

  bucket_name        = aws_s3_bucket.example.id
  bucket_dependency  = aws_s3_bucket_versioning.example

  lifecycle_rules = [
    {
      id      = "cleanup-old-versions"
      enabled = true
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name | Name of the S3 bucket to configure lifecycle rules for | `string` | n/a | yes |
| lifecycle_rules | List of lifecycle rules (see structure below) | `list(object)` | n/a | yes |
| bucket_dependency | Optional dependency on bucket creation/configuration | `any` | `null` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

### Lifecycle Rule Structure

```hcl
{
  id      = string           # Unique identifier for the rule
  enabled = bool             # Whether the rule is enabled (default: true)

  # Filter (optional) - choose one
  filter = {
    prefix = string          # Simple prefix filter
    # OR
    tag = {                  # Single tag filter
      key   = string
      value = string
    }
    # OR
    and = {                  # Combination filter
      prefix = string        # optional
      tags   = map(string)   # optional
    }
  }

  # Actions (at least one required)
  expiration = {
    days                         = number  # Days after creation
    # OR
    date                         = string  # ISO 8601 date
    # OR
    expired_object_delete_marker = bool    # Delete expired delete markers
  }

  noncurrent_version_expiration = {
    noncurrent_days = number   # Days after becoming noncurrent
  }

  abort_incomplete_multipart_upload = {
    days_after_initiation = number   # Days after upload initiation
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the bucket with lifecycle configuration |
| lifecycle_rules | Configured lifecycle rules |
| lifecycle_configuration_id | ID of the lifecycle configuration resource |
| rule_count | Number of lifecycle rules configured |
| enabled_rules | List of enabled rule IDs |

## Provider Configuration

This module uses the AWS provider. Configure it for Scality:

```hcl
provider "aws" {
  alias  = "scality"

  region     = "us-east-1"
  endpoints {
    s3 = "https://s3.scality.example.com"
  }

  access_key = var.scality_access_key
  secret_key = var.scality_secret_key

  # Scality-specific settings
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}

module "lifecycle" {
  source = "../s3-bucket-lifecycle"

  providers = {
    aws = aws.scality
  }

  bucket_name = "my-bucket"
  lifecycle_rules = [
    # ... rules here
  ]
}
```

## Supported Operations

### PUT Bucket Lifecycle

Creates or updates the lifecycle configuration for a bucket.

```bash
# Applied when: terraform apply
```

### GET Bucket Lifecycle

Retrieves the current lifecycle configuration.

```bash
# Applied when: terraform plan, terraform refresh
```

### DELETE Bucket Lifecycle

Removes the lifecycle configuration from a bucket.

```bash
# Applied when: terraform destroy
```

## Validation Rules

The module includes built-in validation:

1. **At least one action**: Each rule must have at least one of: `expiration`, `noncurrent_version_expiration`, or `abort_incomplete_multipart_upload`

2. **Expiration exclusivity**: When using `expiration`, you must specify EITHER:
   - `days` (number)
   - `date` (ISO 8601 string)
   - `expired_object_delete_marker` (boolean)

   You cannot combine multiple options.

## Common Use Cases

### 1. Log Retention

Automatically delete logs after 90 days:

```hcl
lifecycle_rules = [
  {
    id      = "log-retention"
    enabled = true
    filter  = { prefix = "logs/" }
    expiration = { days = 90 }
  }
]
```

### 2. Version Management

Keep current versions, delete old versions after 30 days:

```hcl
lifecycle_rules = [
  {
    id      = "version-cleanup"
    enabled = true
    noncurrent_version_expiration = {
      noncurrent_days = 30
    }
  }
]
```

### 3. Multipart Upload Cleanup

Abort incomplete uploads after 7 days to save storage:

```hcl
lifecycle_rules = [
  {
    id      = "multipart-cleanup"
    enabled = true
    abort_incomplete_multipart_upload = {
      days_after_initiation = 7
    }
  }
]
```

### 4. Temporary Data Cleanup

Delete temporary files tagged as "temp":

```hcl
lifecycle_rules = [
  {
    id      = "temp-cleanup"
    enabled = true
    filter = {
      tag = {
        key   = "Lifecycle"
        value = "Temporary"
      }
    }
    expiration = { days = 1 }
  }
]
```

## Troubleshooting

### Error: "NoSuchLifecycleConfiguration"

This is normal when running `terraform plan` on a bucket that doesn't have lifecycle configuration yet. The module will create it on `terraform apply`.

### Error: "Transition not supported"

Scality does not support transition actions. Remove any `transition` or `noncurrent_version_transition` blocks from your configuration.

### Bucket Versioning Required

To use `noncurrent_version_expiration`, the bucket must have versioning enabled:

```hcl
resource "aws_s3_bucket_versioning" "example" {
  bucket = aws_s3_bucket.example.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

## Examples

See the [examples/](./examples/) directory for complete working examples:

- `basic/` - Simple expiration rules
- `versioned-bucket/` - Version management
- `multi-rule/` - Multiple rules with different filters
- `complete/` - Comprehensive example with all features

## License

This module is provided as-is for use with Scality systems.

## Contributing

When contributing to this module, please ensure:

1. All examples are tested against a Scality system
2. Documentation is updated for any new features
3. Validation rules are added for new inputs
4. No transition-related features are added (not supported by Scality)

## Author

Scality Terraform Modules Team
