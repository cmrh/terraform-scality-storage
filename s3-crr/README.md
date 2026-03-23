# S3 Cross-Region Replication (CRR) Module

Configure Cross-Region Replication between Scality RING/Zenko buckets using Terraform.

## Features

- Bidirectional CRR configuration
- Automatic IAM policy and role creation
- Bucket versioning management
- Optional bucket creation
- Scality Backbeat integration

## Prerequisites

- Terraform >= 1.0
- AWS Provider >= 4.0
- Credentials for source and destination Scality endpoints

## Quick Start

**Set credentials via environment variables** (recommended):

```bash
export SCALITY_SOURCE_ACCESS_KEY="source-access-key"
export SCALITY_SOURCE_SECRET_KEY="source-secret-key"
export SCALITY_DESTINATION_ACCESS_KEY="dest-access-key"
export SCALITY_DESTINATION_SECRET_KEY="dest-secret-key"
```

**Configure providers** (both use `aws` type with aliases for Scality S3 compatibility):

```hcl
provider "aws" {
  alias      = "source"
  region     = "us-east-1"
  access_key = var.source_access_key
  secret_key = var.source_secret_key

  endpoints {
    s3  = "https://source.scality.local"
    iam = "https://source.scality.local"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style          = true
}

provider "aws" {
  alias      = "destination"
  region     = "us-west-2"
  access_key = var.destination_access_key
  secret_key = var.destination_secret_key

  endpoints {
    s3  = "https://destination.scality.local"
    iam = "https://destination.scality.local"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style          = true
}
```

**Use the module:**

```hcl
module "s3_crr" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//s3-crr"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  source_bucket_name      = "my-source-bucket"
  destination_bucket_name = "my-destination-bucket"
  source_endpoint         = "https://source.scality.local"
  destination_endpoint    = "https://destination.scality.local"

  # Credentials from environment variables
  source_access_key      = var.source_access_key
  source_secret_key      = var.source_secret_key
  destination_access_key = var.destination_access_key
  destination_secret_key = var.destination_secret_key

  create_source_bucket      = true
  create_destination_bucket = true

  tags = {
    Environment = "production"
  }
}
```

> **Security**: Never hardcode credentials in `.tf` files. Always use environment variables or a secure secrets manager.

## Variables

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

1. Creates IAM policies and roles on both source and destination
2. Enables bucket versioning (required for CRR)
3. Configures replication from source to destination
4. Uses Scality Backbeat service for replication

**Scality-Specific Settings:**
- `assume_role_principal = "backbeat"` - Scality's replication service
- `s3_use_path_style = true` - Required for Scality endpoints

## Deployment

```bash
# Set environment variables for credentials
export SCALITY_SOURCE_ACCESS_KEY="..."
export SCALITY_SOURCE_SECRET_KEY="..."
export SCALITY_DESTINATION_ACCESS_KEY="..."
export SCALITY_DESTINATION_SECRET_KEY="..."

# Deploy
terraform init
terraform plan
terraform apply
```

## Verify Replication

```bash
# Upload test object
aws --endpoint-url https://source.scality.local \
  s3 cp test.txt s3://my-source-bucket/

# Check destination
aws --endpoint-url https://destination.scality.local \
  s3 ls s3://my-destination-bucket/
```

## Troubleshooting

**Provider errors**: Verify endpoints are set correctly for S3, IAM, and STS
**Account ID not detected**: Set `source_account_id` and `destination_account_id` explicitly

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
