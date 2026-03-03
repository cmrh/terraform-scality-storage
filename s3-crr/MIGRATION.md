# Migration Guide: Bash Script to Terraform Module

This guide helps you migrate from the existing bash script (`enable_crr_api.bash`) to the Terraform module.

## Quick Comparison

| Bash Script | Terraform Module |
|-------------|------------------|
| `./enable_crr_api.bash src-bucket src-profile dst-bucket dst-profile` | `terraform apply` with configured variables |
| `--policy-name my-policy` | `policy_name = "my-policy"` |
| `--role-name my-role` | `role_name = "my-role"` |
| `--create-bucket` | `create_source_bucket = true` |
| AWS profiles in `~/.aws/credentials` | Provider configuration with credentials |

## Migration Steps

### Step 1: Identify Your Current Configuration

From your current bash script usage, identify:

```bash
# Example bash script command:
./enable_crr_api.bash \
  my-source-bucket \
  source-profile \
  my-dest-bucket \
  dest-profile \
  --policy-name my-crr-policy \
  --role-name my-crr-role \
  --create-bucket
```

Extract these values:
- Source bucket: `my-source-bucket`
- Source profile: `source-profile` (check `~/.aws/credentials`)
- Destination bucket: `my-dest-bucket`
- Destination profile: `dest-profile` (check `~/.aws/credentials`)
- Policy name: `my-crr-policy`
- Role name: `my-crr-role`
- Create bucket: `true`

### Step 2: Extract AWS Profile Information

Look up your AWS profiles in `~/.aws/credentials`:

```ini
[source-profile]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
endpoint_url = https://source.scality.local
region = us-east-1

[dest-profile]
aws_access_key_id = AKIAI44QH8DHBEXAMPLE
aws_secret_access_key = je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY
endpoint_url = https://destination.scality.local
region = us-west-2
```

### Step 3: Create Terraform Configuration

Create a new directory for your Terraform configuration:

```bash
mkdir my-crr-config
cd my-crr-config
```

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

# Source provider
provider "aws" {
  alias      = "source"
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

# Destination provider
provider "aws" {
  alias      = "destination"
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

# Module invocation
module "s3_crr" {
  source = "../terraform-s3-crr-module"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  source_bucket_name      = "my-source-bucket"
  destination_bucket_name = "my-dest-bucket"

  source_endpoint      = "https://source.scality.local"
  destination_endpoint = "https://destination.scality.local"

  source_access_key      = var.source_access_key
  source_secret_key      = var.source_secret_key
  destination_access_key = var.destination_access_key
  destination_secret_key = var.destination_secret_key

  policy_name = "my-crr-policy"
  role_name   = "my-crr-role"

  create_source_bucket      = true
  create_destination_bucket = true

  tags = {
    ManagedBy   = "Terraform"
    Environment = "production"
  }
}

output "summary" {
  value = module.s3_crr.summary
}
```

Create `variables.tf`:

```hcl
variable "source_access_key" {
  type      = string
  sensitive = true
}

variable "source_secret_key" {
  type      = string
  sensitive = true
}

variable "destination_access_key" {
  type      = string
  sensitive = true
}

variable "destination_secret_key" {
  type      = string
  sensitive = true
}
```

Create `terraform.tfvars`:

```hcl
source_access_key      = "AKIAIOSFODNN7EXAMPLE"
source_secret_key      = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
destination_access_key = "AKIAI44QH8DHBEXAMPLE"
destination_secret_key = "je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY"
```

### Step 4: Import Existing Resources (If Applicable)

If you've already run the bash script and have existing resources, you can import them:

```bash
# Initialize Terraform
terraform init

# Import source bucket (if it exists)
terraform import 'module.s3_crr.aws_s3_bucket.source[0]' my-source-bucket

# Import destination bucket (if it exists)
terraform import 'module.s3_crr.aws_s3_bucket.destination[0]' my-dest-bucket

# Import IAM resources
terraform import 'module.s3_crr.aws_iam_policy.source_crr' arn:aws:iam::ACCOUNT_ID:policy/my-crr-policy
terraform import 'module.s3_crr.aws_iam_role.source_crr' my-crr-role

# Repeat for destination resources...
```

**Note**: Importing can be complex. For a fresh start, consider:
1. Document current configuration with the bash script
2. Destroy old resources manually
3. Create new resources with Terraform

### Step 5: Plan and Apply

```bash
# Review what will be created
terraform plan

# Apply the configuration
terraform apply
```

## Key Differences

### 1. State Management

**Bash Script:**
- No state tracking
- Re-running may cause errors if resources exist
- Manual cleanup required

**Terraform:**
- Maintains state file
- Idempotent operations
- `terraform destroy` for cleanup

### 2. Error Handling

**Bash Script:**
- Exits on first error
- Manual rollback needed

**Terraform:**
- Validates before applying
- Automatic rollback on failure
- Shows detailed error messages

### 3. Credentials

**Bash Script:**
```ini
# ~/.aws/credentials
[profile-name]
aws_access_key_id = ...
```

**Terraform:**
```hcl
# In provider configuration
provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
}
```

### 4. Resource Naming

**Bash Script:**
- Auto-generates names with timestamp
- Example: `crr-policy-1673625600`

**Terraform:**
- Uses variables or auto-generation
- Consistent across runs with same config
- Can be explicitly set

### 5. Verification

**Bash Script:**
```bash
# Check logs
cat /tmp/enable_crr.*
```

**Terraform:**
```bash
# View state
terraform show

# View specific outputs
terraform output summary
```

## Benefits of Migration

1. **Version Control**: Infrastructure as code in Git
2. **Collaboration**: Team can review changes via PRs
3. **Consistency**: Same configuration produces same results
4. **Documentation**: Code is documentation
5. **Automation**: CI/CD integration
6. **Safety**: Plan before apply
7. **Rollback**: Easy to revert changes
8. **Scalability**: Manage multiple CRR setups

## Rollback Plan

If you need to rollback to the bash script:

1. Export Terraform state information:
   ```bash
   terraform output -json > crr-config.json
   ```

2. Terraform destroy (if needed):
   ```bash
   terraform destroy
   ```

3. Re-run bash script:
   ```bash
   ./enable_crr_api.bash \
     my-source-bucket \
     source-profile \
     my-dest-bucket \
     dest-profile \
     --policy-name my-crr-policy \
     --role-name my-crr-role
   ```

## Best Practices

1. **Use Remote State**: Store state in S3 or Terraform Cloud
   ```hcl
   terraform {
     backend "s3" {
       bucket = "my-terraform-state"
       key    = "crr/terraform.tfstate"
       region = "us-east-1"
     }
   }
   ```

2. **Use Workspaces**: Separate dev/staging/prod
   ```bash
   terraform workspace new production
   terraform workspace select production
   ```

3. **Secure Credentials**: Use environment variables or secret management
   ```bash
   export TF_VAR_source_access_key="..."
   export TF_VAR_source_secret_key="..."
   terraform apply
   ```

4. **Version Control**: Commit everything except secrets
   ```bash
   git add main.tf variables.tf outputs.tf .gitignore
   git commit -m "Add CRR Terraform configuration"
   ```

5. **Documentation**: Add README with team-specific instructions

## Support

For issues or questions:
1. Check the [main README](README.md)
2. Review [examples](examples/basic/)
3. Check Terraform AWS provider docs
4. Review Scality documentation

## Checklist

- [ ] Identified all parameters from bash script
- [ ] Extracted credentials from AWS profiles
- [ ] Created Terraform configuration files
- [ ] Added to version control (.gitignore for secrets)
- [ ] Ran `terraform init`
- [ ] Reviewed `terraform plan`
- [ ] Applied configuration
- [ ] Verified replication works
- [ ] Documented any custom changes
- [ ] Shared with team
