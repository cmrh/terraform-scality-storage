# Basic Lifecycle Example

This example demonstrates basic lifecycle rules:
- Expiring logs after 90 days
- Aborting incomplete multipart uploads after 7 days

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
