# S3 Bucket Module

Terraform module for creating and configuring S3 buckets on Scality on-premises storage.

## Features

- Bucket creation with versioning
- Server-side encryption (SSE-S3 or SSE-KMS)
- Access control (ACL and bucket policies)
- CORS configuration
- Website hosting
- Object lock (WORM compliance)
- Event notifications
- Tagging and public access controls

## Quick Start

**Set credentials via environment variables:**

```bash
export SCALITY_S3_ENDPOINT="http://scality.example.com"
export SCALITY_ACCESS_KEY="your-access-key"
export SCALITY_SECRET_KEY="your-secret-key"
```

**Configure provider:**

```hcl
provider "aws" {
  region = "us-east-1"

  endpoints {
    s3 = var.s3_endpoint  # From environment
  }

  access_key = var.access_key
  secret_key = var.secret_key

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}
```

**Create a bucket:**

```hcl
module "bucket" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//s3-bucket"

  bucket_name = "my-bucket"
  tags = {
    Environment = "production"
  }
}
```

## Examples

### Versioned Bucket with Encryption

```hcl
module "secure_bucket" {
  source = "../s3-bucket"

  bucket_name          = "my-secure-bucket"
  versioning_enabled   = true
  enable_encryption    = true
  encryption_algorithm = "AES256"
}
```

### Website Hosting

```hcl
module "website" {
  source = "../s3-bucket"

  bucket_name             = "my-website"
  acl                     = "public-read"
  enable_website_hosting  = true
  website_index_document  = "index.html"
  enable_public_access_block = false
}
```

### Compliance Bucket (Object Lock)

```hcl
module "compliance" {
  source = "../s3-bucket"

  bucket_name        = "compliance-bucket"
  versioning_enabled = true
  enable_object_lock = true

  object_lock_retention = {
    mode = "COMPLIANCE"
    days = 365
  }
}
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

## Supported Operations

All standard S3 bucket operations supported by Scality including versioning, encryption, ACL, policies, CORS, website hosting, object lock, replication, notifications, and tagging.

## License

Apache 2.0
