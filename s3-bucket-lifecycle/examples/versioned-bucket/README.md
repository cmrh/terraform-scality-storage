# Versioned Bucket Lifecycle Example

This example demonstrates lifecycle rules for versioned buckets:
- Expiring current versions after 365 days
- Expiring noncurrent versions after 90 days
- Removing expired object delete markers
- Aborting incomplete multipart uploads

## Prerequisites

The bucket must have versioning enabled to use noncurrent version expiration rules.

## Usage

```bash
# Set credentials
export TF_VAR_s3_endpoint="https://s3.scality.example.com"
export TF_VAR_access_key="your-access-key"
export TF_VAR_secret_key="your-secret-key"

# Initialize and apply
tofu init
tofu plan
tofu apply

# Cleanup
tofu destroy
```

## What This Does

1. Creates a versioned S3 bucket
2. Configures lifecycle rules to:
   - Keep current versions for 1 year
   - Keep old versions for 90 days
   - Clean up delete markers
   - Abort stale multipart uploads
