# Using S3 Backend for Terraform State with Scality

This guide explains how to store Terraform/OpenTofu state files in a Scality S3 bucket, including how to solve the bootstrap problem when the bucket doesn't exist yet.

## Overview

Storing Terraform state in S3 provides:
- **Collaboration** - Multiple team members can work on the same infrastructure
- **State Locking** - Prevents concurrent modifications (with DynamoDB)
- **Versioning** - Track state file history
- **Encryption** - Secure storage of sensitive data
- **Backup** - Automatic backup and recovery

## Prerequisites

- Access to a Scality S3 endpoint
- Account admin credentials (from Scality provider)
- Terraform >= 1.0 or OpenTofu >= 1.6
- AWS CLI (optional, for bucket management)

## The Bootstrap Problem

**Problem**: You need an S3 bucket to store state, but you need Terraform to create the bucket, but Terraform needs somewhere to store its state about the bucket.

**Solution**: Two-phase approach:
1. **Phase 1**: Use local state to create the S3 bucket
2. **Phase 2**: Migrate state to the S3 bucket

## Solution 1: Bootstrap Module (Recommended)

### Step 1: Create Bootstrap Configuration

Create a directory for bootstrap resources:

```bash
mkdir -p terraform-bootstrap
cd terraform-bootstrap
```

Create `main.tf`:

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Use LOCAL backend for bootstrap
  # This will be replaced with S3 backend after bucket creation
}

# Configure AWS provider to use Scality
provider "aws" {
  region = "us-east-1"

  endpoints {
    s3 = var.scality_endpoint
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  # Allow HTTP for local/development
  insecure = var.use_https ? false : true
}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  tags = {
    Name        = "Terraform State Bucket"
    Purpose     = "terraform-state"
    ManagedBy   = "terraform-bootstrap"
  }
}

# Enable versioning for state bucket
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Optional: Enable server-side encryption (if supported by Scality)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Create state file directory structure
resource "aws_s3_object" "state_directories" {
  for_each = toset([
    "account-management/",
    "infrastructure/",
    "applications/",
  ])

  bucket       = aws_s3_bucket.terraform_state.id
  key          = each.value
  content_type = "application/x-directory"
}

# Output bucket information
output "bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "backend_configuration" {
  description = "Backend configuration to use in other Terraform projects"
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket   = "${aws_s3_bucket.terraform_state.bucket}"
        key      = "path/to/terraform.tfstate"
        region   = "us-east-1"
        endpoint = "${var.scality_endpoint}"

        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        force_path_style           = true
      }
    }
  EOT
}
```

Create `variables.tf`:

```hcl
variable "scality_endpoint" {
  description = "Scality S3 endpoint URL"
  type        = string
  default     = "http://10.164.169.247"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "terraform-state"
}

variable "use_https" {
  description = "Use HTTPS for Scality endpoint"
  type        = bool
  default     = false
}

variable "enable_encryption" {
  description = "Enable server-side encryption (if supported by Scality)"
  type        = bool
  default     = false
}
```

### Step 2: Run Bootstrap

```bash
# Set account admin credentials
export AWS_ACCESS_KEY_ID="your-account-admin-access-key"
export AWS_SECRET_ACCESS_KEY="your-account-admin-secret-key"

# Initialize Terraform (local backend)
terraform init

# Create the state bucket
terraform apply

# Save the backend configuration
terraform output -raw backend_configuration > backend.tf
```

### Step 3: Migrate Bootstrap State to S3

Now migrate the bootstrap state itself to S3:

Edit `main.tf` and add backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "bootstrap/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

Migrate the state:

```bash
# Re-initialize with new backend
terraform init -migrate-state

# Confirm migration
# The local terraform.tfstate file can now be deleted
```

### Step 4: Use S3 Backend in Other Projects

In your other Terraform projects, add backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "account-management/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

Initialize with backend:

```bash
terraform init
```

## Solution 2: Manual Bucket Creation

If you prefer to create the bucket manually:

### Step 1: Create Bucket with AWS CLI

```bash
# Set credentials
export AWS_ACCESS_KEY_ID="your-account-admin-access-key"
export AWS_SECRET_ACCESS_KEY="your-account-admin-secret-key"

# Create bucket
aws s3 mb s3://terraform-state --endpoint-url http://10.164.169.247

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket terraform-state \
  --versioning-configuration Status=Enabled \
  --endpoint-url http://10.164.169.247

# Verify bucket
aws s3 ls --endpoint-url http://10.164.169.247
```

### Step 2: Configure Backend in Terraform

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

## Backend Configuration Options

### Basic Configuration

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "path/to/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    # Required for Scality
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

### With Encryption (if supported)

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "path/to/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    encrypt                     = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

### With Custom Credentials

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "path/to/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    access_key = var.backend_access_key
    secret_key = var.backend_secret_key

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

**Note**: Variables cannot be used directly in backend configuration. Use partial configuration instead:

Create `backend.hcl`:
```hcl
bucket     = "terraform-state"
key        = "my-project/terraform.tfstate"
region     = "us-east-1"
endpoint   = "http://10.164.169.247"
access_key = "your-access-key"
secret_key = "your-secret-key"

skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
force_path_style            = true
```

Initialize with:
```bash
terraform init -backend-config=backend.hcl
```

## State File Organization

### Recommended Directory Structure

```
s3://terraform-state/
├── bootstrap/
│   └── terraform.tfstate
├── account-management/
│   ├── dev/
│   │   └── terraform.tfstate
│   ├── staging/
│   │   └── terraform.tfstate
│   └── prod/
│       └── terraform.tfstate
├── infrastructure/
│   ├── networking/
│   │   └── terraform.tfstate
│   └── security/
│       └── terraform.tfstate
└── applications/
    ├── app1/
    │   └── terraform.tfstate
    └── app2/
        └── terraform.tfstate
```

### Use Workspaces for Environments

Alternative to directory structure:

```hcl
terraform {
  backend "s3" {
    bucket   = "terraform-state"
    key      = "account-management/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "http://10.164.169.247"

    # Workspace will be appended to key
    # dev:     account-management/terraform.tfstate.d/dev/terraform.tfstate
    # staging: account-management/terraform.tfstate.d/staging/terraform.tfstate
    # prod:    account-management/terraform.tfstate.d/prod/terraform.tfstate

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

Usage:
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

terraform workspace select dev
terraform apply
```

## Migrating Existing Local State to S3

### Method 1: Using -migrate-state Flag

```bash
# 1. Add backend configuration to your Terraform files
cat >> main.tf <<EOF
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
EOF

# 2. Re-initialize with migration
terraform init -migrate-state

# 3. Verify migration
aws s3 ls s3://terraform-state/my-project/ --endpoint-url http://10.164.169.247

# 4. Backup and remove local state
cp terraform.tfstate terraform.tfstate.backup
rm terraform.tfstate terraform.tfstate.backup
```

### Method 2: Manual State Push

```bash
# 1. Configure backend
terraform init

# 2. Manually push existing state
terraform state push terraform.tfstate

# 3. Verify
terraform state pull
```

## State Locking with DynamoDB

**Note**: Scality may not support DynamoDB. If DynamoDB is available:

### Create DynamoDB Table

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform State Lock Table"
  }
}
```

### Configure Backend with Locking

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "path/to/terraform.tfstate"
    region         = "us-east-1"
    endpoint       = "http://10.164.169.247"
    dynamodb_table = "terraform-state-locks"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  }
}
```

## Security Best Practices

### 1. Restrict Bucket Access

Create a policy that limits access to the state bucket:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketVersioning"
      ],
      "Resource": "arn:aws:s3:::terraform-state"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::terraform-state/*"
    }
  ]
}
```

### 2. Use Separate Credentials

Create a dedicated IAM user for Terraform state access:

```hcl
# In your account-management module
module "terraform_state_user" {
  source = "path/to/scality-account-management"

  scality_endpoint = var.scality_endpoint

  policies = {
    terraform_state_access = {
      description = "Access to Terraform state bucket"
      policy_document = file("policies/terraform-state.json")
    }
  }

  users = {
    terraform_state = {
      policies = ["terraform_state_access"]
      tags = {
        Purpose = "Terraform State Management"
      }
    }
  }
}
```

### 3. Enable Versioning

Always enable versioning to recover from accidental deletions or corruption:

```bash
aws s3api put-bucket-versioning \
  --bucket terraform-state \
  --versioning-configuration Status=Enabled \
  --endpoint-url http://10.164.169.247
```

### 4. Protect Backend Configuration

```bash
# Never commit backend credentials
echo "backend.hcl" >> .gitignore
echo "*.tfbackend" >> .gitignore

# Use environment variables for credentials
export AWS_ACCESS_KEY_ID="state-bucket-access-key"
export AWS_SECRET_ACCESS_KEY="state-bucket-secret-key"
```

## Troubleshooting

### Error: Failed to get existing workspaces

```
Error: Failed to get existing workspaces: SignatureDoesNotMatch
```

**Solution**: Check credentials and endpoint:
```bash
# Test S3 access
aws s3 ls --endpoint-url http://10.164.169.247

# Verify credentials
echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
```

### Error: Error loading state

```
Error: Error loading state: NoSuchBucket: The specified bucket does not exist
```

**Solution**: Create the bucket first:
```bash
aws s3 mb s3://terraform-state --endpoint-url http://10.164.169.247
```

### Error: RequestTimeTooSkewed

```
Error: RequestTimeTooSkewed: The difference between the request time and the current time is too large
```

**Solution**: Sync system clock:
```bash
sudo ntpdate -s time.nist.gov
# Or
sudo timedatectl set-ntp true
```

### State File Corruption

**Recovery from S3 versioning**:

```bash
# List versions
aws s3api list-object-versions \
  --bucket terraform-state \
  --prefix my-project/terraform.tfstate \
  --endpoint-url http://10.164.169.247

# Download previous version
aws s3api get-object \
  --bucket terraform-state \
  --key my-project/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.recovered \
  --endpoint-url http://10.164.169.247

# Restore
terraform state push terraform.tfstate.recovered
```

## Complete Bootstrap Example

Here's a complete working example:

### Directory Structure

```
terraform-bootstrap/
├── main.tf
├── variables.tf
├── outputs.tf
└── README.md
```

### Full main.tf

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  endpoints {
    s3 = var.scality_endpoint
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true
  insecure                    = !var.use_https
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  tags = {
    Name      = "Terraform State Bucket"
    Purpose   = "terraform-state"
    ManagedBy = "terraform-bootstrap"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "next_steps" {
  value = <<-EOT
    Terraform state bucket created successfully!

    Next steps:
    1. Add this backend configuration to your Terraform projects:

    terraform {
      backend "s3" {
        bucket   = "${aws_s3_bucket.terraform_state.bucket}"
        key      = "YOUR_PROJECT/terraform.tfstate"
        region   = "us-east-1"
        endpoint = "${var.scality_endpoint}"

        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        force_path_style            = true
      }
    }

    2. Run 'terraform init' to initialize the backend

    3. (Optional) Migrate this bootstrap state to S3:
       - Add the backend configuration above to this project
       - Run 'terraform init -migrate-state'
  EOT
}
```

### Usage

```bash
# 1. Clone/create bootstrap directory
mkdir terraform-bootstrap
cd terraform-bootstrap

# 2. Create configuration files (shown above)

# 3. Set credentials
export AWS_ACCESS_KEY_ID="account-admin-access-key"
export AWS_SECRET_ACCESS_KEY="account-admin-secret-key"

# 4. Initialize and apply
terraform init
terraform apply

# 5. Follow output instructions
terraform output -raw next_steps
```

## Best Practices Summary

1. ✅ **Always enable versioning** on state buckets
2. ✅ **Use separate credentials** for state bucket access
3. ✅ **Organize state files** in logical directory structure
4. ✅ **Never commit** backend credential files
5. ✅ **Use workspaces** for environment separation
6. ✅ **Regularly backup** state files outside of S3
7. ✅ **Test state recovery** procedures periodically
8. ✅ **Document backend configuration** for team members
9. ✅ **Use HTTPS** in production environments
10. ✅ **Implement access controls** on state bucket

## References

- [Terraform S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [OpenTofu S3 Backend Documentation](https://opentofu.org/docs/language/settings/backends/s3/)
- [AWS S3 API Documentation](https://docs.aws.amazon.com/AmazonS3/latest/API/)
- [Scality Provider Documentation](../../Providers/terraform-provider-scality/docs/)
