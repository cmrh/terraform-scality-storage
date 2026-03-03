# S3 Bucket Module

Comprehensive Terraform/OpenTofu module for creating and configuring S3 buckets on Scality with all supported operations.

## Features

Complete implementation of all Scality-supported S3 bucket operations:

- **Bucket Creation** - Create S3 buckets with location constraints
- **Versioning** - Enable/suspend bucket versioning
- **Encryption** - Default server-side encryption (SSE-S3 or SSE-KMS)
- **ACL** - Canned ACLs or custom access control
- **Bucket Policy** - JSON policy documents
- **CORS** - Cross-origin resource sharing configuration
- **Website Hosting** - Static website hosting with routing rules
- **Object Lock** - WORM (Write Once Read Many) compliance
- **Replication** - Cross-region replication setup
- **Notifications** - Event notifications (SNS, SQS, Lambda)
- **Tagging** - Bucket tags
- **Public Access Block** - Control public access

## Quick Start

```hcl
module "bucket" {
  source = "../s3-bucket"

  bucket_name = "my-bucket"
  tags = {
    Environment = "production"
  }
}
```

## Usage Examples

### Basic Bucket

```hcl
module "simple_bucket" {
  source = "../s3-bucket"

  bucket_name = "my-simple-bucket"
  acl         = "private"

  tags = {
    Project = "MyProject"
  }
}
```

### Versioned Bucket with Encryption

```hcl
module "versioned_bucket" {
  source = "../s3-bucket"

  bucket_name        = "my-versioned-bucket"
  versioning_enabled = true
  enable_encryption  = true
  encryption_algorithm = "AES256"

  tags = {
    Versioned = "true"
    Encrypted = "true"
  }
}
```

### Public Website Hosting

```hcl
module "website_bucket" {
  source = "../s3-bucket"

  bucket_name = "my-website"
  acl         = "public-read"

  enable_website_hosting  = true
  website_index_document  = "index.html"
  website_error_document  = "error.html"

  enable_public_access_block = false

  cors_rules = [
    {
      allowed_methods = ["GET", "HEAD"]
      allowed_origins = ["*"]
    }
  ]
}
```

### Bucket with Object Lock

```hcl
module "compliant_bucket" {
  source = "../s3-bucket"

  bucket_name        = "compliance-bucket"
  versioning_enabled = true  # Required for object lock
  enable_object_lock = true

  object_lock_retention = {
    mode = "COMPLIANCE"
    days = 365
  }
}
```

## Standard Environment Variables

This module uses standardized environment variable names (compatible with other Scality modules):

- `SCALITY_S3_ENDPOINT` - S3 endpoint URL
- `SCALITY_ACCESS_KEY` - Access key
- `SCALITY_SECRET_KEY` - Secret key
- `SCALITY_REGION` - AWS region (default: us-east-1)

Configure your provider:

```hcl
provider "aws" {
  region = var.region

  endpoints {
    s3 = var.s3_endpoint
  }

  access_key = var.access_key
  secret_key = var.secret_key

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}
```

Set variables via environment:

```bash
export TF_VAR_s3_endpoint="$SCALITY_S3_ENDPOINT"
export TF_VAR_access_key="$SCALITY_ACCESS_KEY"
export TF_VAR_secret_key="$SCALITY_SECRET_KEY"
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name | Bucket name (must be globally unique) | string | n/a | yes |
| force_destroy | Allow destruction even with objects | bool | false | no |
| versioning_enabled | Enable versioning | bool | null | no |
| enable_encryption | Enable default encryption | bool | false | no |
| encryption_algorithm | Encryption algorithm (AES256 or aws:kms) | string | "AES256" | no |
| acl | Canned ACL | string | null | no |
| bucket_policy | Bucket policy JSON | string | null | no |
| cors_rules | CORS configuration | list(object) | [] | no |
| enable_website_hosting | Enable website hosting | bool | false | no |
| enable_object_lock | Enable object lock | bool | false | no |
| enable_replication | Enable replication | bool | false | no |
| enable_notifications | Enable notifications | bool | false | no |
| tags | Bucket tags | map(string) | {} | no |

See [variables.tf](./variables.tf) for complete list.

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | Bucket ID |
| bucket_arn | Bucket ARN |
| bucket_name | Bucket name |
| bucket_domain_name | Bucket domain name |
| versioning_enabled | Versioning status |
| encryption_enabled | Encryption status |
| website_endpoint | Website endpoint (if enabled) |

## Examples

See the [examples/](./examples/) directory:

- `basic/` - Simple bucket creation
- `versioned/` - Versioned bucket with encryption
- `encrypted/` - Bucket with KMS encryption
- `complete/` - Full-featured configuration

## Supported Scality Operations

Based on [Scality S3C documentation](https://github.com/scality/cloudserver):

- ✅ PUT Bucket - Create bucket
- ✅ DELETE Bucket - Delete bucket
- ✅ HEAD Bucket - Check bucket existence
- ✅ PUT Bucket Versioning - Configure versioning
- ✅ GET Bucket Versioning - Read versioning state
- ✅ PUT Bucket Encryption - Configure encryption
- ✅ GET Bucket Encryption - Read encryption config
- ✅ DELETE Bucket Encryption - Remove encryption
- ✅ PUT Bucket ACL - Set ACL
- ✅ GET Bucket ACL - Read ACL
- ✅ PUT Bucket Policy - Set policy
- ✅ GET Bucket Policy - Read policy
- ✅ DELETE Bucket Policy - Remove policy
- ✅ PUT Bucket Tagging - Set tags
- ✅ GET Bucket Tagging - Read tags
- ✅ DELETE Bucket Tagging - Remove tags
- ✅ PUT Bucket CORS - Configure CORS
- ✅ GET Bucket CORS - Read CORS
- ✅ DELETE Bucket CORS - Remove CORS
- ✅ PUT Bucket Website - Configure website
- ✅ GET Bucket Website - Read website config
- ✅ DELETE Bucket Website - Remove website
- ✅ PUT Bucket Replication - Configure replication
- ✅ GET Bucket Replication - Read replication
- ✅ DELETE Bucket Replication - Remove replication
- ✅ PUT Bucket Notification - Configure notifications
- ✅ GET Bucket Notification - Read notifications
- ✅ PUT Object Lock Configuration - Configure object lock
- ✅ GET Object Lock Configuration - Read object lock

## License

Apache 2.0

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.
