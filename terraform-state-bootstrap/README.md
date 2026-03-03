# Terraform State Bootstrap Module

This module solves the "chicken and egg" problem of storing Terraform state in S3 by creating the initial state bucket using local state, then optionally migrating the bootstrap state to S3.

## Quick Start

### Step 1: Create the State Bucket

```bash
# Navigate to bootstrap module
cd terraform-state-bootstrap

# Set account admin credentials
export AWS_ACCESS_KEY_ID="your-account-admin-access-key"
export AWS_SECRET_ACCESS_KEY="your-account-admin-secret-key"

# Initialize with local backend
terraform init

# Create the state bucket
terraform apply

# View next steps
terraform output -raw next_steps
```

### Step 2: Use S3 Backend in Other Projects

Copy the backend configuration from the output:

```bash
terraform output -raw backend_config > ../my-project/backend.tf
```

Or manually add to your project's `main.tf`:

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "my-project/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

### Step 3: Migrate Bootstrap State (Optional)

To store the bootstrap state in S3:

1. Edit `main.tf` and uncomment the backend configuration
2. Re-initialize with migration:
   ```bash
   terraform init -migrate-state
   ```
3. Confirm the migration when prompted

## Features

- ✅ Creates S3 bucket for Terraform state
- ✅ Enables versioning for state recovery
- ✅ Optional server-side encryption
- ✅ Optional lifecycle rules for old versions
- ✅ Organized directory structure
- ✅ Comprehensive documentation in bucket

## Usage

### Basic Usage

```hcl
# Use default settings
terraform apply -var="scality_endpoint=http://10.164.169.247"
```

### Custom Configuration

```hcl
terraform apply \
  -var="scality_endpoint=http://10.164.169.247" \
  -var="state_bucket_name=my-terraform-state" \
  -var="enable_encryption=true" \
  -var="old_version_retention_days=30"
```

### With Variables File

Create `terraform.tfvars`:

```hcl
scality_endpoint            = "http://10.164.169.247"
state_bucket_name           = "my-org-terraform-state"
use_https                   = false
enable_encryption           = false
enable_lifecycle_rules      = true
old_version_retention_days  = 90

state_directories = [
  "bootstrap",
  "account-management",
  "networking",
  "security",
  "applications",
  "databases"
]

tags = {
  Organization = "MyOrg"
  Environment  = "Production"
  ManagedBy    = "Terraform"
}
```

Apply:

```bash
terraform apply
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| scality_endpoint | Scality S3 endpoint URL | `string` | n/a | yes |
| state_bucket_name | Name of the S3 bucket for Terraform state | `string` | `"terraform-state"` | no |
| use_https | Use HTTPS for connections | `bool` | `false` | no |
| enable_encryption | Enable server-side encryption | `bool` | `false` | no |
| enable_lifecycle_rules | Enable lifecycle rules for old versions | `bool` | `true` | no |
| old_version_retention_days | Days to retain old state versions | `number` | `90` | no |
| state_directories | Directories to create for organization | `list(string)` | See below | no |
| directory_descriptions | Descriptions for directories | `map(string)` | See below | no |
| tags | Additional tags for the bucket | `map(string)` | `{}` | no |

### Default State Directories

```hcl
[
  "bootstrap",
  "account-management",
  "infrastructure",
  "applications",
]
```

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the Terraform state bucket |
| bucket_arn | ARN of the Terraform state bucket |
| bucket_region | Region of the state bucket |
| versioning_enabled | Whether versioning is enabled |
| backend_config | Backend configuration block |
| backend_config_file | Backend config for -backend-config file |
| aws_cli_example | Example AWS CLI command |
| next_steps | Detailed next steps instructions |

## State File Organization

The module creates a logical directory structure in the bucket:

```
s3://terraform-state/
├── README.md
├── bootstrap/
│   └── (this module's state after migration)
├── account-management/
│   └── (Scality account and IAM management)
├── infrastructure/
│   └── (networking, security, etc.)
└── applications/
    └── (application deployments)
```

### Using the Directory Structure

```hcl
# Account management project
terraform {
  backend "s3" {
    key = "account-management/prod.tfstate"
    # ... other config
  }
}

# Networking project
terraform {
  backend "s3" {
    key = "infrastructure/networking.tfstate"
    # ... other config
  }
}

# Application project
terraform {
  backend "s3" {
    key = "applications/web-app.tfstate"
    # ... other config
  }
}
```

## State Recovery

### List All State Versions

```bash
aws s3api list-object-versions \
  --bucket terraform-state \
  --prefix my-project/terraform.tfstate \
  --endpoint-url http://10.164.169.247 \
  --query 'Versions[*].[VersionId,LastModified,IsLatest]' \
  --output table
```

### Download Previous Version

```bash
aws s3api get-object \
  --bucket terraform-state \
  --key my-project/terraform.tfstate \
  --version-id VERSION_ID_HERE \
  recovered-state.tfstate \
  --endpoint-url http://10.164.169.247
```

### Restore Previous Version

```bash
# Push recovered state
terraform state push recovered-state.tfstate

# Verify
terraform state pull
```

## Migration Examples

### Migrate Existing Local State

If you have existing projects with local state:

```bash
# 1. Add backend configuration to existing project
cat >> main.tf <<'EOF'
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "existing-project/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
EOF

# 2. Re-initialize and migrate
terraform init -migrate-state

# 3. Verify migration
aws s3 ls s3://terraform-state/existing-project/ --endpoint-url http://10.164.169.247

# 4. Backup and remove local state
cp terraform.tfstate terraform.tfstate.local.backup
rm terraform.tfstate*
```

### Migrate Bootstrap State Itself

After creating the state bucket, migrate the bootstrap state to S3:

```bash
# 1. Edit main.tf and uncomment the backend block
sed -i 's/# backend/backend/g' main.tf

# 2. Migrate
terraform init -migrate-state

# 3. Verify
terraform state pull | head -20
```

## Security Best Practices

### 1. Use Dedicated Service Account

Create a dedicated user for state bucket access:

```hcl
module "terraform_state_user" {
  source = "../scality-account-management"

  scality_endpoint = var.scality_endpoint

  policies = {
    terraform_state = {
      description = "Access to Terraform state bucket"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "s3:ListBucket",
              "s3:GetBucketVersioning"
            ]
            Resource = "arn:aws:s3:::terraform-state"
          },
          {
            Effect = "Allow"
            Action = [
              "s3:GetObject",
              "s3:PutObject",
              "s3:DeleteObject"
            ]
            Resource = "arn:aws:s3:::terraform-state/*"
          }
        ]
      })
    }
  }

  users = {
    terraform_ci = {
      policies = ["terraform_state"]
    }
  }
}
```

### 2. Environment Variable Management

```bash
# Store in secure location
cat > ~/.terraform-state-credentials <<'EOF'
export AWS_ACCESS_KEY_ID="state-bucket-access-key"
export AWS_SECRET_ACCESS_KEY="state-bucket-secret-key"
EOF

chmod 600 ~/.terraform-state-credentials

# Source when needed
source ~/.terraform-state-credentials
```

### 3. Never Commit Credentials

```bash
echo "*.tfvars" >> .gitignore
echo "backend.hcl" >> .gitignore
echo "*.tfbackend" >> .gitignore
echo ".terraform/" >> .gitignore
echo "terraform.tfstate*" >> .gitignore
```

## Troubleshooting

### Issue: Bucket Already Exists

```
Error: Error creating S3 bucket: BucketAlreadyExists
```

**Solution**: Choose a different bucket name or import existing bucket:

```bash
terraform import aws_s3_bucket.terraform_state terraform-state
```

### Issue: Access Denied

```
Error: error creating S3 bucket: AccessDenied
```

**Solution**: Verify credentials have S3 permissions:

```bash
aws s3 ls --endpoint-url http://10.164.169.247
```

### Issue: State Lock Timeout

```
Error acquiring the state lock: ConditionalCheckFailedException
```

**Solution**: Manually unlock (use with caution):

```bash
terraform force-unlock LOCK_ID
```

## Clean Up

To destroy the state bucket (WARNING: This will delete all state files):

```bash
# List what will be destroyed
terraform plan -destroy

# WARNING: This deletes all Terraform state files!
# Only do this if you're sure you want to delete everything
terraform destroy
```

## See Also

- [S3 Backend Documentation](../scality-account-management/docs/S3_BACKEND.md) - Detailed guide
- [Scality Account Management Module](../scality-account-management/) - For creating IAM users
- [Terraform S3 Backend](https://www.terraform.io/docs/language/settings/backends/s3.html) - Official docs

## License

This module is provided as-is for use with Scality storage systems.
