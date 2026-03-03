# Terraform S3 Cross-Region Replication (CRR) Module

This Terraform module configures Cross-Region Replication (CRR) for S3-compatible storage systems, specifically designed for Scality RING/Zenko but compatible with AWS S3 as well.

## Features

- ✅ Configures bidirectional CRR between source and destination buckets
- ✅ Creates and manages IAM policies and roles
- ✅ Enables bucket versioning automatically
- ✅ Supports custom S3 endpoints (Scality/Zenko)
- ✅ Optional bucket creation
- ✅ Customizable replication prefix and status
- ✅ Complete idempotency and state management

## Architecture

This module creates the following resources:

**On Source Account:**
- IAM Policy with CRR permissions
- IAM Role with trust relationship to Backbeat service
- S3 Bucket (optional)
- Bucket versioning configuration
- Replication configuration

**On Destination Account:**
- IAM Policy with CRR permissions
- IAM Role with trust relationship to Backbeat service
- S3 Bucket (optional)
- Bucket versioning configuration

## Prerequisites

- Terraform >= 1.0
- AWS Provider >= 4.0
- Valid credentials for both source and destination environments
- S3-compatible endpoints (Scality/Zenko/AWS)

## Understanding Provider Configuration

**Why do both providers use "aws" as the type?**

This module requires managing two separate S3-compatible endpoints (source and destination). Since Scality is S3-compatible, we use the AWS provider for both endpoints. To differentiate between them, Terraform uses **provider aliases**:

```hcl
provider "aws" {
  alias = "source"      # First instance - manages source endpoint
  # source-specific configuration
}

provider "aws" {
  alias = "destination" # Second instance - manages destination endpoint
  # destination-specific configuration
}
```

These aliases allow you to:
- Configure two different endpoints using the same provider type
- Pass different credentials to each provider
- Reference them separately: `aws.source` and `aws.destination`

**Visual representation:**
```
┌─────────────────────────────────────────────────────────┐
│  provider "aws" (type)                                  │
│  ┌──────────────────┐       ┌──────────────────┐       │
│  │  alias="source"  │       │ alias="destination"│     │
│  │  ├─ endpoint A   │       │  ├─ endpoint B   │       │
│  │  ├─ creds A      │       │  ├─ creds B      │       │
│  │  └─ region A     │       │  └─ region B     │       │
│  └──────────────────┘       └──────────────────┘       │
│         ↓                            ↓                  │
│    aws.source               aws.destination            │
└─────────────────────────────────────────────────────────┘
```

## Security

🔒 **Important**: This module supports secure credential management through environment variables.

**Recommended approach**: Use environment variables instead of hard-coding credentials.

See [SECURITY.md](SECURITY.md) for complete security best practices.

### Quick Start: Environment Variables

```bash
# Set credentials via environment variables
export SCALITY_SOURCE_ACCESS_KEY="your-source-access-key"
export SCALITY_SOURCE_SECRET_KEY="your-source-secret-key"
export SCALITY_DESTINATION_ACCESS_KEY="your-dest-access-key"
export SCALITY_DESTINATION_SECRET_KEY="your-dest-secret-key"

# Run Terraform - credentials are automatically picked up
terraform apply
```

## Usage

### Secure Example (Environment Variables) ✅ Recommended

```hcl
module "s3_crr" {
  source = "./terraform-s3-crr-module"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  # Bucket configuration
  source_bucket_name      = "my-source-bucket"
  destination_bucket_name = "my-destination-bucket"

  # Endpoint configuration
  source_endpoint      = "https://source.scality.local"
  destination_endpoint = "https://destination.scality.local"

  # Credentials are read from environment variables:
  # - SCALITY_SOURCE_ACCESS_KEY
  # - SCALITY_SOURCE_SECRET_KEY
  # - SCALITY_DESTINATION_ACCESS_KEY
  # - SCALITY_DESTINATION_SECRET_KEY
  # No need to specify them here!

  # Optional: Create buckets if they don't exist
  create_source_bucket      = true
  create_destination_bucket = true

  # Optional: Custom names
  policy_name = "my-crr-policy"
  role_name   = "my-crr-role"

  # Tags
  tags = {
    Environment = "production"
    Project     = "data-replication"
  }
}
```

### Complete Example with Provider Configuration

**Important Note on Provider Aliasing:**
Both providers use the same `aws` provider type (because Scality is S3-compatible), but they are differentiated by their `alias` attribute:
- First provider has `alias = "source"` → Referenced as `aws.source`
- Second provider has `alias = "destination"` → Referenced as `aws.destination`

This allows us to manage two different S3-compatible endpoints using the same provider type.

Create a `main.tf` file in your root module:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# ============================================================================
# SOURCE PROVIDER - Manages resources on the source Scality endpoint
# ============================================================================
# NOTE: This provider block uses "aws" as the type (for S3 compatibility)
# but has alias = "source" to differentiate it from the destination provider
provider "aws" {
  alias      = "source"  # This makes it referenceable as "aws.source"
  region     = "us-east-1"
  access_key = var.source_access_key
  secret_key = var.source_secret_key

  endpoints {
    s3  = "https://source.scality.local"
    iam = "https://source.scality.local"
    sts = "https://source.scality.local"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = false
  s3_use_path_style          = true
}

# ============================================================================
# DESTINATION PROVIDER - Manages resources on the destination Scality endpoint
# ============================================================================
# NOTE: This provider block also uses "aws" as the type (for S3 compatibility)
# but has alias = "destination" to differentiate it from the source provider
provider "aws" {
  alias      = "destination"  # This makes it referenceable as "aws.destination"
  region     = "us-west-2"
  access_key = var.destination_access_key
  secret_key = var.destination_secret_key

  endpoints {
    s3  = "https://destination.scality.local"
    iam = "https://destination.scality.local"
    sts = "https://destination.scality.local"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = false
  s3_use_path_style          = true
}

# ============================================================================
# MODULE INVOCATION - Passes both providers to the module
# ============================================================================
module "s3_crr" {
  source = "./terraform-s3-crr-module"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  source_bucket_name      = "my-source-bucket"
  destination_bucket_name = "my-destination-bucket"
  source_endpoint         = "https://source.scality.local"
  destination_endpoint    = "https://destination.scality.local"

  source_access_key      = var.source_access_key
  source_secret_key      = var.source_secret_key
  destination_access_key = var.destination_access_key
  destination_secret_key = var.destination_secret_key

  create_source_bucket      = true
  create_destination_bucket = true

  tags = {
    ManagedBy = "Terraform"
  }
}

# Outputs
output "crr_summary" {
  value = module.s3_crr.summary
}
```

Create a `variables.tf`:

```hcl
variable "source_access_key" {
  description = "Source AWS access key"
  type        = string
  sensitive   = true
}

variable "source_secret_key" {
  description = "Source AWS secret key"
  type        = string
  sensitive   = true
}

variable "destination_access_key" {
  description = "Destination AWS access key"
  type        = string
  sensitive   = true
}

variable "destination_secret_key" {
  description = "Destination AWS secret key"
  type        = string
  sensitive   = true
}
```

Create a `terraform.tfvars` (add to .gitignore):

```hcl
source_access_key      = "AKIAIOSFODNN7EXAMPLE"
source_secret_key      = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
destination_access_key = "AKIAI44QH8DHBEXAMPLE"
destination_secret_key = "je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY"
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| source_bucket_name | Name of the source S3 bucket | `string` | n/a | yes |
| destination_bucket_name | Name of the destination S3 bucket | `string` | n/a | yes |
| source_endpoint | S3 endpoint URL for source | `string` | n/a | yes |
| destination_endpoint | S3 endpoint URL for destination | `string` | n/a | yes |
| source_access_key | AWS access key for source | `string` | n/a | yes |
| source_secret_key | AWS secret key for source | `string` | n/a | yes |
| destination_access_key | AWS access key for destination | `string` | n/a | yes |
| destination_secret_key | AWS secret key for destination | `string` | n/a | yes |
| source_region | AWS region for source bucket | `string` | `"us-east-1"` | no |
| destination_region | AWS region for destination bucket | `string` | `"us-east-1"` | no |
| create_source_bucket | Whether to create the source bucket | `bool` | `false` | no |
| create_destination_bucket | Whether to create the destination bucket | `bool` | `false` | no |
| policy_name | Name for the IAM policy | `string` | `""` (auto-generated) | no |
| role_name | Name for the IAM trust role | `string` | `""` (auto-generated) | no |
| replication_prefix | Prefix for objects to replicate | `string` | `""` (all objects) | no |
| replication_status | Status of replication (Enabled/Disabled) | `string` | `"Enabled"` | no |
| assume_role_principal | Service principal for assume role | `string` | `"backbeat"` | no |
| source_account_id | Source account ID (if not auto-detected) | `string` | `""` | no |
| destination_account_id | Destination account ID (if not auto-detected) | `string` | `""` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| source_bucket_name | Name of the source bucket |
| source_bucket_arn | ARN of the source bucket |
| source_account_id | Source account ID |
| source_policy_arn | ARN of the source IAM policy |
| source_role_arn | ARN of the source IAM role |
| destination_bucket_name | Name of the destination bucket |
| destination_bucket_arn | ARN of the destination bucket |
| destination_account_id | Destination account ID |
| destination_policy_arn | ARN of the destination IAM policy |
| destination_role_arn | ARN of the destination IAM role |
| replication_configuration_id | ID of the replication configuration |
| summary | Complete summary of all CRR configuration |

## How It Works

1. **Provider Configuration**: Uses Terraform provider aliases to manage two separate S3/IAM environments
2. **Account Discovery**: Retrieves account IDs via STS GetCallerIdentity
3. **IAM Setup**: Creates policies and roles with appropriate permissions
4. **S3 Configuration**: Enables versioning (required for CRR) and configures replication
5. **Dependency Management**: Ensures resources are created in the correct order

## Scality-Specific Configuration

This module is designed for Scality with the following defaults:

- `assume_role_principal = "backbeat"` (Scality's replication service)
- `force_path_style = true` (required for Scality)
- `skip_credentials_validation = true`
- `skip_metadata_api_check = true`

## Deployment Steps

1. **Initialize Terraform**:
   ```bash
   terraform init
   ```

2. **Review the plan**:
   ```bash
   terraform plan
   ```

3. **Apply the configuration**:
   ```bash
   terraform apply
   ```

4. **Verify replication**:
   ```bash
   # Upload a test object to source
   aws --profile source --endpoint-url https://source.scality.local \
     s3 cp test.txt s3://my-source-bucket/

   # Check if it replicates to destination
   aws --profile destination --endpoint-url https://destination.scality.local \
     s3 ls s3://my-destination-bucket/
   ```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Note**: This will remove all IAM policies, roles, and optionally the buckets (if created by Terraform). Replication configurations will be removed.

## Comparison to Original Bash Script

| Feature | Bash Script | This Terraform Module |
|---------|-------------|----------------------|
| Idempotency | Manual | Automatic (state-managed) |
| Error Handling | Exit on error | Rollback on error |
| Resource Tracking | None | Full state tracking |
| Credentials | AWS profiles | Provider configuration |
| Validation | Runtime | Plan-time |
| Rollback | Manual | Automatic |
| Audit Trail | Logs only | State + logs |
| Reusability | Script execution | Module import |

## Troubleshooting

### Issue: Provider configuration errors

**Solution**: Ensure endpoints are correctly set for S3, IAM, and STS.

### Issue: Account ID not detected

**Solution**: Set `source_account_id` and `destination_account_id` explicitly.

### Issue: Replication not working

**Solution**:
1. Verify versioning is enabled on both buckets
2. Check IAM role permissions
3. Verify Backbeat service is running (Scality)
4. Check bucket policies for cross-account access

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This module is provided as-is for use with Scality and AWS S3-compatible systems.

## Authors

Generated from Scality CRR bash script implementation.

## References

- [Scality Documentation](https://documentation.scality.com/)
- [AWS S3 Replication](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
