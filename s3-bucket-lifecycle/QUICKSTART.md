# Quick Start Guide

Get started with the S3 Bucket Lifecycle module in 5 minutes.

## Prerequisites

- OpenTofu (or Terraform) >= 1.0 installed
- Scality S3 credentials (access key and secret key)
- Existing S3 bucket OR permissions to create one

## Step 1: Create a New Directory

```bash
mkdir my-lifecycle-config
cd my-lifecycle-config
```

## Step 2: Create Configuration File

Create `main.tf`:

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

# Configure provider for Scality
provider "aws" {
  region = "us-east-1"

  endpoints {
    s3 = "https://s3.scality.example.com"  # Change to your endpoint
  }

  access_key = "YOUR_ACCESS_KEY"
  secret_key = "YOUR_SECRET_KEY"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}

# Use the lifecycle module
module "lifecycle" {
  source = "path/to/s3-bucket-lifecycle"

  bucket_name = "my-bucket-name"

  lifecycle_rules = [
    # Delete logs after 90 days
    {
      id      = "expire-logs"
      enabled = true
      filter = {
        prefix = "logs/"
      }
      expiration = {
        days = 90
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

output "configured_rules" {
  value = module.lifecycle.enabled_rules
}
```

## Step 3: Initialize OpenTofu

```bash
tofu init
```

## Step 4: Review the Plan

```bash
tofu plan
```

You should see output showing the lifecycle configuration that will be created.

## Step 5: Apply the Configuration

```bash
tofu apply
```

Type `yes` when prompted.

## Step 6: Verify

Check that lifecycle rules were applied:

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket my-bucket-name \
  --endpoint-url https://s3.scality.example.com
```

## Using Environment Variables (Recommended)

Instead of hardcoding credentials, use environment variables:

### Create `main.tf`:

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

module "lifecycle" {
  source = "path/to/s3-bucket-lifecycle"

  bucket_name = var.bucket_name

  lifecycle_rules = [
    {
      id      = "cleanup-old-data"
      enabled = true
      expiration = {
        days = 90
      }
    }
  ]
}
```

### Create `variables.tf`:

```hcl
variable "region" {
  type    = string
  default = "us-east-1"
}

variable "s3_endpoint" {
  type = string
}

variable "access_key" {
  type      = string
  sensitive = true
}

variable "secret_key" {
  type      = string
  sensitive = true
}

variable "bucket_name" {
  type = string
}
```

### Set Environment Variables:

```bash
export TF_VAR_s3_endpoint="https://s3.scality.example.com"
export TF_VAR_access_key="your-access-key"
export TF_VAR_secret_key="your-secret-key"
export TF_VAR_bucket_name="my-bucket"
```

### Run:

```bash
tofu init
tofu apply
```

## Common Scenarios

### Scenario 1: Log Retention

Keep logs for 30 days:

```hcl
lifecycle_rules = [
  {
    id      = "log-retention"
    enabled = true
    filter  = { prefix = "logs/" }
    expiration = { days = 30 }
  }
]
```

### Scenario 2: Versioned Bucket Cleanup

For versioned buckets, clean up old versions:

```hcl
# Enable versioning first
resource "aws_s3_bucket_versioning" "example" {
  bucket = "my-bucket"
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure lifecycle
module "lifecycle" {
  source            = "path/to/s3-bucket-lifecycle"
  bucket_name       = "my-bucket"
  bucket_dependency = aws_s3_bucket_versioning.example

  lifecycle_rules = [
    {
      id      = "cleanup-versions"
      enabled = true
      noncurrent_version_expiration = {
        noncurrent_days = 30
      }
    }
  ]
}
```

### Scenario 3: Temporary Files

Delete files tagged as temporary after 7 days:

```hcl
lifecycle_rules = [
  {
    id      = "temp-cleanup"
    enabled = true
    filter = {
      tag = {
        key   = "Type"
        value = "Temporary"
      }
    }
    expiration = { days = 7 }
  }
]
```

## Troubleshooting

### Issue: "NoSuchBucket"
**Solution**: Ensure the bucket exists before applying lifecycle rules.

### Issue: "NoSuchLifecycleConfiguration" during plan
**Solution**: This is normal for buckets without existing lifecycle configuration.

### Issue: "InvalidArgument: Transitions are not supported"
**Solution**: Remove any `transition` or `noncurrent_version_transition` blocks. Scality only supports expiration and abort actions.

### Issue: Noncurrent version expiration not working
**Solution**: Ensure bucket versioning is enabled:
```hcl
resource "aws_s3_bucket_versioning" "example" {
  bucket = "my-bucket"
  versioning_configuration {
    status = "Enabled"
  }
}
```

## Next Steps

1. Check out the [examples/](./examples/) directory for more advanced use cases
2. Read the full [README.md](./README.md) for detailed documentation
3. Explore filtering options (prefix, tags, combined)
4. Set up multiple rules for different data types

## Cleanup

To remove the lifecycle configuration:

```bash
tofu destroy
```

This will remove the lifecycle rules but NOT delete the bucket or its contents.
