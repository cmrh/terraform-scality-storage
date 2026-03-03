# S3 Bucket Lifecycle Module - Summary

## Overview

A complete OpenTofu/Terraform module for managing S3 bucket lifecycle policies on Scality systems. This module provides a clean, reusable way to configure lifecycle rules for automatic object expiration and cleanup.

## What Was Built

A production-ready Terraform module that wraps the `aws_s3_bucket_lifecycle_configuration` resource with intelligent defaults, validation, and comprehensive examples.

## Module Structure

```
s3-bucket-lifecycle/
├── main.tf                     # Core lifecycle configuration resource
├── variables.tf                # Input variables with validation
├── outputs.tf                  # Module outputs
├── versions.tf                 # Provider version constraints
├── README.md                   # Complete documentation
├── QUICKSTART.md              # 5-minute getting started guide
├── .gitignore                 # Git ignore rules
├── MODULE_SUMMARY.md          # This file
├── docs/                      # Additional documentation (empty, ready for expansion)
└── examples/                  # Working examples
    ├── basic/                 # Simple expiration rules
    │   ├── main.tf
    │   ├── variables.tf
    │   └── README.md
    ├── versioned-bucket/      # Version management
    │   ├── main.tf
    │   ├── variables.tf
    │   └── README.md
    ├── multi-rule/            # Multiple rules with different filters
    │   ├── main.tf
    │   ├── variables.tf
    │   └── README.md
    └── complete/              # Comprehensive example
        ├── main.tf
        ├── variables.tf
        └── README.md
```

## Key Features

### 1. Supported Lifecycle Actions

- **Expiration**: Delete objects based on age or date
  - Days-based expiration (e.g., delete after 90 days)
  - Date-based expiration (e.g., delete on 2026-12-31)
  - Expired object delete marker cleanup

- **Noncurrent Version Expiration**: Clean up old versions in versioned buckets
  - Configurable retention period for old versions

- **Abort Incomplete Multipart Uploads**: Automatically abort stale uploads
  - Saves storage space from incomplete uploads

### 2. Flexible Filtering

- **Prefix filtering**: Target objects by path prefix (`logs/`, `data/`, etc.)
- **Tag filtering**: Target objects by single tag
- **Combined filtering**: Prefix + multiple tags using AND logic

### 3. Multiple Rules Support

Configure multiple lifecycle rules on a single bucket with different:
- Filters (prefix, tags, combinations)
- Actions (expiration, version cleanup, multipart abort)
- Enable/disable individual rules

### 4. Built-in Validation

- At least one action required per rule
- Expiration type exclusivity (days XOR date XOR delete markers)
- Input validation for all parameters

## Scality Limitations (By Design)

**Important**: This module only supports operations that Scality provides:

✅ **Supported**:
- `put_bucket_lifecycle` - Create/update lifecycle configuration
- `get_bucket_lifecycle` - Read lifecycle configuration
- `delete_bucket_lifecycle` - Remove lifecycle configuration

❌ **NOT Supported** (by Scality):
- Transition policies (moving objects between storage classes)
- `noncurrent_version_transition`
- Intelligent tiering

The module is specifically designed to work within these constraints.

## Usage Example

### Basic Usage

```hcl
module "lifecycle" {
  source = "path/to/s3-bucket-lifecycle"

  bucket_name = "my-bucket"

  lifecycle_rules = [
    {
      id      = "expire-logs"
      enabled = true
      filter  = { prefix = "logs/" }
      expiration = { days = 90 }
    }
  ]
}
```

### Advanced Usage

```hcl
module "lifecycle" {
  source = "path/to/s3-bucket-lifecycle"

  bucket_name = "my-versioned-bucket"

  lifecycle_rules = [
    # Current version expiration
    {
      id      = "expire-current"
      enabled = true
      expiration = { days = 365 }
    },

    # Old version cleanup
    {
      id      = "expire-versions"
      enabled = true
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    },

    # Tag-based cleanup
    {
      id      = "expire-temp"
      enabled = true
      filter = {
        tag = {
          key   = "Lifecycle"
          value = "Temporary"
        }
      }
      expiration = { days = 7 }
    },

    # Multipart cleanup
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

## Input Variables

| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `bucket_name` | string | Yes | Name of the S3 bucket |
| `lifecycle_rules` | list(object) | Yes | List of lifecycle rules (see structure below) |
| `bucket_dependency` | any | No | Optional dependency on bucket creation |
| `tags` | map(string) | No | Tags to apply to resources |

### Lifecycle Rule Object Structure

```hcl
{
  id      = string           # Unique identifier
  enabled = bool             # Default: true

  # Filter (optional)
  filter = {
    prefix = string          # OR
    tag = { key, value }     # OR
    and = { prefix, tags }   # Combined
  }

  # Actions (at least one required)
  expiration = {
    days                         = number
    date                         = string
    expired_object_delete_marker = bool
  }

  noncurrent_version_expiration = {
    noncurrent_days = number
  }

  abort_incomplete_multipart_upload = {
    days_after_initiation = number
  }
}
```

## Outputs

| Output | Description |
|--------|-------------|
| `bucket_name` | Name of the configured bucket |
| `lifecycle_rules` | Complete rules configuration |
| `lifecycle_configuration_id` | Resource ID |
| `rule_count` | Number of rules |
| `enabled_rules` | List of enabled rule IDs |

## Examples Provided

### 1. Basic Example
Simple log expiration and multipart upload cleanup.

**Use case**: Quick setup for basic lifecycle management.

### 2. Versioned Bucket Example
Complete version management with current/noncurrent version expiration.

**Use case**: Versioned buckets needing version retention policies.

### 3. Multi-Rule Example
Multiple rules with different filters (prefix, tags, combinations).

**Use case**: Complex buckets with different data retention requirements.

### 4. Complete Example
Comprehensive demonstration of all features.

**Use case**: Reference implementation showing all capabilities.

## Provider Configuration

The module uses the AWS provider configured for Scality:

```hcl
provider "aws" {
  region = "us-east-1"

  endpoints {
    s3 = "https://s3.scality.example.com"
  }

  access_key = var.access_key
  secret_key = var.secret_key

  # Required for Scality
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}
```

## Common Use Cases

### 1. Log Retention
Automatically delete logs after a retention period:
```hcl
filter = { prefix = "logs/" }
expiration = { days = 90 }
```

### 2. Version Management
Keep current versions, expire old versions after 30 days:
```hcl
noncurrent_version_expiration = {
  noncurrent_days = 30
}
```

### 3. Temporary Data Cleanup
Delete files tagged as temporary:
```hcl
filter = {
  tag = { key = "Type", value = "Temporary" }
}
expiration = { days = 1 }
```

### 4. Multipart Upload Cleanup
Abort incomplete uploads to save storage:
```hcl
abort_incomplete_multipart_upload = {
  days_after_initiation = 7
}
```

### 5. Environment-Specific Retention
Different retention for dev vs. production:
```hcl
# Dev: 14 days
filter = {
  and = {
    prefix = "data/"
    tags = { Environment = "dev" }
  }
}
expiration = { days = 14 }

# Production: 365 days
filter = {
  and = {
    prefix = "data/"
    tags = { Environment = "production" }
  }
}
expiration = { days = 365 }
```

## Validation Rules

The module includes comprehensive input validation:

1. **Action Requirement**: Each rule must have at least one action
2. **Expiration Exclusivity**: Can't mix days, date, and delete markers
3. **Type Safety**: All inputs are strongly typed
4. **Optional Defaults**: Sensible defaults for optional parameters

## Testing

All examples are designed to be runnable:

```bash
cd examples/basic
export TF_VAR_s3_endpoint="https://s3.scality.example.com"
export TF_VAR_access_key="your-key"
export TF_VAR_secret_key="your-secret"

tofu init
tofu plan
tofu apply
```

## Documentation

- **README.md**: Complete module documentation with all features
- **QUICKSTART.md**: 5-minute getting started guide
- **Example READMEs**: Specific guidance for each example
- **Inline Comments**: Well-commented code throughout

## Best Practices Implemented

1. **DRY Principle**: Reusable module, not duplicated code
2. **Validation**: Input validation at the variable level
3. **Documentation**: Comprehensive docs with examples
4. **Flexibility**: Supports simple to complex use cases
5. **Type Safety**: Strongly typed variables
6. **Dependencies**: Proper dependency management
7. **Outputs**: Useful outputs for downstream consumption
8. **Security**: No credentials in code, use environment variables
9. **Standards**: Follows Terraform/OpenTofu best practices
10. **Examples**: Multiple working examples for different scenarios

## Integration with Other Modules

This module can be used alongside:

- **s3-crr**: Cross-region replication module
- **scality-account-management**: Account provisioning
- **terraform-state-bootstrap**: Remote state setup

Example:
```hcl
# Create account
module "account" {
  source = "../scality-account-management"
  # ...
}

# Create bucket with CRR
module "crr" {
  source = "../s3-crr"
  # ...
}

# Add lifecycle rules
module "lifecycle" {
  source      = "../s3-bucket-lifecycle"
  bucket_name = module.crr.source_bucket_name
  # ...
}
```

## Maintenance

### Adding New Rules
Simply add to the `lifecycle_rules` list in your configuration.

### Disabling Rules
Set `enabled = false` on individual rules.

### Removing Rules
Remove from the list and apply.

### Updating Rules
Modify the rule parameters and apply.

## Troubleshooting

### Common Issues

**"NoSuchLifecycleConfiguration" during plan**
- Normal for buckets without existing lifecycle config
- Will be created on apply

**"InvalidArgument: Transitions not supported"**
- Scality doesn't support transitions
- Remove any transition-related configuration

**Noncurrent version expiration not working**
- Bucket versioning must be enabled
- Add `aws_s3_bucket_versioning` resource

## Version Compatibility

- **Terraform/OpenTofu**: >= 1.0
- **AWS Provider**: >= 4.0
- **Scality**: Tested with RING 8.x

## Future Enhancements

Potential additions (based on Scality capabilities):
- Additional filter types if supported
- Integration with monitoring/alerting
- Lifecycle policy templates
- Cost estimation helpers

## Files Manifest

| File | Purpose | Lines |
|------|---------|-------|
| `main.tf` | Core resource configuration | ~70 |
| `variables.tf` | Input variables with validation | ~80 |
| `outputs.tf` | Module outputs | ~25 |
| `versions.tf` | Provider constraints | ~10 |
| `README.md` | Complete documentation | ~500 |
| `QUICKSTART.md` | Getting started guide | ~300 |
| `.gitignore` | Git ignore patterns | ~35 |
| `examples/*/` | Working examples | ~150 each |

## Success Criteria

✅ Complete lifecycle configuration support
✅ All Scality-supported operations implemented
✅ Flexible filtering (prefix, tags, combinations)
✅ Input validation
✅ Comprehensive documentation
✅ Multiple working examples
✅ Type-safe variables
✅ Useful outputs
✅ Follows Terraform best practices
✅ Ready for production use

## Module Complete!

This module is fully functional and ready to use for managing S3 bucket lifecycle policies on Scality systems. It provides a clean, declarative way to automate object expiration and cleanup.

## Quick Links

- [README.md](./README.md) - Full documentation
- [QUICKSTART.md](./QUICKSTART.md) - Getting started in 5 minutes
- [examples/basic/](./examples/basic/) - Simple example
- [examples/complete/](./examples/complete/) - Comprehensive example
