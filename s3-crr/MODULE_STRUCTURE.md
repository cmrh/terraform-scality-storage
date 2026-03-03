# Module Structure

This document describes the structure and organization of the Terraform S3 CRR module.

## Directory Layout

```
terraform-s3-crr-module/
├── README.md                          # Main module documentation
├── MIGRATION.md                       # Bash script migration guide
├── TESTING.md                         # Testing procedures
├── MODULE_STRUCTURE.md               # This file
├── .gitignore                        # Git ignore rules
│
├── Core Module Files
├── versions.tf                       # Terraform version constraints
├── providers.tf                      # Provider configuration
├── variables.tf                      # Input variable definitions
├── data.tf                           # Data sources (account IDs)
├── iam.tf                            # IAM policies and roles
├── s3.tf                             # S3 buckets and replication
├── outputs.tf                        # Output definitions
│
└── examples/
    └── basic/                        # Basic usage example
        ├── README.md                 # Example documentation
        ├── main.tf                   # Example configuration
        ├── variables.tf              # Example variables
        ├── outputs.tf                # Example outputs
        └── terraform.tfvars.example  # Example variable values
```

## File Purposes

### Root Module Files

#### `versions.tf`
- Defines minimum Terraform version (>= 1.0)
- Specifies required providers (AWS >= 4.0)
- No actual provider configuration (done by caller)

#### `providers.tf`
- Declares provider aliases: `aws.source` and `aws.destination`
- Configuration aliases allow multi-provider setup
- Actual configuration passed from calling module

#### `variables.tf`
- **31 input variables** for module configuration
- Includes:
  - Bucket names and endpoints
  - Credentials (marked sensitive)
  - Optional flags (create buckets, etc.)
  - Customization options (policy/role names)
  - Scality-specific settings (backbeat principal)
  - Tags for resource labeling

#### `data.tf`
- **Data sources**: Fetches account IDs via STS
- **Local values**: Computed values like timestamps, names
- Handles auto-generation of policy/role names
- Provides fallback for manual account IDs

#### `iam.tf`
- Creates **4 IAM resources** total:
  - 2 IAM policies (source and destination)
  - 2 IAM roles (source and destination)
  - 2 policy attachments
- Policy permissions:
  - GetObjectVersion, GetObjectVersionAcl
  - ListBucket, GetReplicationConfiguration
  - ReplicateObject, ReplicateDelete
- Trust policy with configurable principal (default: "backbeat")

#### `s3.tf`
- **S3 bucket creation** (conditional, based on variables)
- **Versioning configuration** (required for CRR)
- **Replication configuration** on source bucket
- Dependency management ensures correct order:
  1. Buckets created
  2. Versioning enabled
  3. IAM resources ready
  4. Replication configured

#### `outputs.tf`
- **15+ outputs** providing:
  - Bucket names and ARNs
  - Account IDs
  - IAM policy and role ARNs
  - Replication status
  - Complete summary object
- Useful for:
  - Verification
  - Integration with other modules
  - Documentation
  - Debugging

### Documentation Files

#### `README.md`
- Comprehensive module documentation
- Features overview
- Architecture diagram (textual)
- Prerequisites
- Usage examples
- Complete input/output reference
- Comparison to bash script
- Troubleshooting guide
- Scality-specific notes

#### `MIGRATION.md`
- Step-by-step migration from bash script
- Side-by-side comparison
- AWS profile extraction
- Import existing resources guide
- Rollback procedures
- Best practices for production migration

#### `TESTING.md`
- Complete testing guide covering:
  - Pre-deployment validation
  - Deployment testing
  - Post-deployment verification
  - Functional replication tests
  - Performance testing
  - Automated testing with Terratest
  - Test checklist
  - Troubleshooting common failures

### Example Directory

#### `examples/basic/`
A complete, runnable example demonstrating module usage:

- **`main.tf`**: Full provider and module configuration
- **`variables.tf`**: Variable declarations
- **`outputs.tf`**: Output forwarding from module
- **`terraform.tfvars.example`**: Sample values
- **`README.md`**: Example-specific documentation

## Module Flow

### 1. Input Phase
```
User provides:
├── Bucket names
├── Endpoints
├── Credentials
├── Optional settings
└── Tags
```

### 2. Data Collection Phase
```
Module retrieves:
├── Source account ID (via STS)
├── Destination account ID (via STS)
└── Generates unique names (if needed)
```

### 3. Resource Creation Phase
```
Resources created in order:
1. S3 Buckets (if create_*_bucket = true)
2. Bucket Versioning (both buckets)
3. IAM Policies (source and destination)
4. IAM Roles (source and destination)
5. Policy Attachments (link roles to policies)
6. Replication Configuration (source bucket)
```

### 4. Output Phase
```
Module outputs:
├── Resource identifiers (ARNs, names)
├── Configuration details
└── Summary object
```

## Resource Naming

### Auto-Generated Names
If `policy_name` or `role_name` not provided:
- Format: `crr-policy-YYYYMMDDhhmmss`
- Format: `crr-trust-role-YYYYMMDDhhmmss`
- Example: `crr-policy-20260113120000`

### Custom Names
If provided via variables:
- Uses exact name specified
- User responsible for uniqueness

## Dependencies

### External Dependencies
```
Terraform >= 1.0
└── AWS Provider >= 4.0
    ├── S3 API
    ├── IAM API
    └── STS API
```

### Resource Dependencies
```
Replication Configuration
├── depends_on: Bucket Versioning (source)
├── depends_on: Bucket Versioning (destination)
├── depends_on: IAM Role (source)
├── depends_on: IAM Role (destination)
├── depends_on: Policy Attachment (source)
└── depends_on: Policy Attachment (destination)

Policy Attachment (source)
├── depends_on: IAM Policy (source)
└── depends_on: IAM Role (source)

Policy Attachment (destination)
├── depends_on: IAM Policy (destination)
└── depends_on: IAM Role (destination)

Bucket Versioning (source)
└── depends_on: S3 Bucket (source) [if created]

Bucket Versioning (destination)
└── depends_on: S3 Bucket (destination) [if created]
```

## Variable Types

### Required Variables (8)
- `source_bucket_name`
- `destination_bucket_name`
- `source_endpoint`
- `destination_endpoint`
- `source_access_key`
- `source_secret_key`
- `destination_access_key`
- `destination_secret_key`

### Optional Variables (23)
- Regions (2): Default `us-east-1`
- Creation flags (2): Default `false`
- Names (2): Default auto-generated
- Replication settings (2): Default `""` and `"Enabled"`
- Principal (1): Default `"backbeat"`
- Account IDs (2): Default auto-detected
- Provider settings (5): Defaults for Scality
- Tags (1): Default `{}`
- Other Scality settings (6)

## Output Categories

### Source Outputs (6)
- bucket_name, bucket_arn
- account_id
- policy_arn
- role_arn, role_name

### Destination Outputs (6)
- bucket_name, bucket_arn
- account_id
- policy_arn
- role_arn, role_name

### Replication Outputs (2)
- configuration_id
- status

### Summary Output (1)
- Complete nested object with all details

## Provider Configuration Pattern

This module uses **provider aliases** pattern:

```hcl
# In module (providers.tf)
terraform {
  required_providers {
    aws = {
      configuration_aliases = [
        aws.source,
        aws.destination
      ]
    }
  }
}

# In caller (main.tf)
provider "aws" {
  alias = "source"
  # ... configuration
}

provider "aws" {
  alias = "destination"
  # ... configuration
}

module "s3_crr" {
  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }
}
```

This pattern allows:
- **Multi-account** setups
- **Multi-region** configurations
- **Custom endpoints** (Scality/Zenko)
- **Different credentials** per provider

## Customization Points

Users can customize:

1. **Bucket creation**: Use existing or create new
2. **Naming**: Auto-generated or custom
3. **Replication scope**: Prefix-based filtering
4. **Replication status**: Enable/disable
5. **Principal**: Change from "backbeat" if needed
6. **Tags**: Add organizational metadata
7. **Regions**: Different per bucket
8. **Endpoints**: Support any S3-compatible API

## State Management

Terraform state tracks:
- **13 resources** (typical with bucket creation)
- **2 data sources** (account IDs)
- **Local values** (computed names)

State file location determined by backend configuration (caller's responsibility).

## Module Versioning

To version this module:

```hcl
module "s3_crr" {
  source = "git::https://github.com/org/terraform-s3-crr-module.git?ref=v1.0.0"
  # ... configuration
}
```

Recommended: Use semantic versioning (v1.0.0, v1.1.0, v2.0.0).

## Extension Points

This module can be extended:

1. **Additional IAM permissions**: Edit `iam.tf`
2. **Bucket policies**: Add new resources
3. **Lifecycle rules**: Add S3 lifecycle configurations
4. **Metrics/monitoring**: Add CloudWatch resources
5. **Notifications**: Add SNS/SQS integration
6. **Encryption**: Add bucket encryption config
7. **Logging**: Add access logging

## Best Practices Implemented

✅ **Separation of concerns**: Each file handles specific resources
✅ **DRY principle**: Variables for all customizable values
✅ **Clear naming**: Descriptive resource and variable names
✅ **Documentation**: Inline comments and external docs
✅ **Validation**: Input validation where applicable
✅ **Outputs**: Comprehensive output coverage
✅ **Dependencies**: Explicit dependency management
✅ **Tagging**: Consistent tag application
✅ **Security**: Sensitive variable marking
✅ **Examples**: Working example included

## Module Maintenance

### Adding a new feature:
1. Add variables to `variables.tf`
2. Add resources to appropriate `.tf` file
3. Add outputs to `outputs.tf`
4. Update `README.md`
5. Update example in `examples/basic/`
6. Add tests to `TESTING.md`

### Updating for new provider version:
1. Update `versions.tf`
2. Test compatibility
3. Update `README.md` prerequisites
4. Update changelog

## Related Scripts

This module is based on:
- **Original script**: `/home/cyrus/Documents/Development/Scality/Develpment/scripts/enable_crr_api.bash`
- **Line count**: ~477 lines of bash
- **Module line count**: ~600 lines of HCL (with docs: 2000+)

## Support Matrix

| Platform | Support Level | Notes |
|----------|--------------|-------|
| Scality RING | ✅ Primary | Designed for this |
| Zenko | ✅ Primary | Compatible |
| AWS S3 | ✅ Compatible | Works with standard AWS |
| MinIO | ⚠️ Untested | Should work with modifications |
| Other S3 | ⚠️ Untested | YMMV |

## Quick Reference

**Module invocation:**
```hcl
module "s3_crr" {
  source = "./terraform-s3-crr-module"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  source_bucket_name      = "bucket-a"
  destination_bucket_name = "bucket-b"
  source_endpoint         = "https://..."
  destination_endpoint    = "https://..."

  # credentials...
}
```

**Typical usage:**
```bash
cd examples/basic
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars
terraform init
terraform plan
terraform apply
```
