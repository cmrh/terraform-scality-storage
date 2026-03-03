# Quick Start Guide

Get up and running with the S3 CRR Terraform module in 5 minutes.

## Prerequisites

- ✅ Terraform >= 1.0 installed
- ✅ Two S3-compatible endpoints (Scality/Zenko/AWS)
- ✅ Access credentials for both endpoints
- ✅ 5 minutes of your time

## Step 1: Clone/Copy the Module

```bash
cd /home/cyrus/Documents/Development/Scality
# Module is already at: terraform-s3-crr-module/
```

## Step 2: Navigate to Example

```bash
cd terraform-s3-crr-module/examples/basic
```

## Step 3: Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# Minimal configuration
source_bucket_name = "my-source-bucket"
source_endpoint    = "https://source.scality.local"
source_access_key  = "YOUR_SOURCE_ACCESS_KEY"
source_secret_key  = "YOUR_SOURCE_SECRET_KEY"

destination_bucket_name = "my-dest-bucket"
destination_endpoint    = "https://destination.scality.local"
destination_access_key  = "YOUR_DEST_ACCESS_KEY"
destination_secret_key  = "YOUR_DEST_SECRET_KEY"

# Create buckets if they don't exist
create_source_bucket      = true
create_destination_bucket = true
```

## Step 4: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Initializing modules...
Initializing the backend...
Initializing provider plugins...
Terraform has been successfully initialized!
```

## Step 5: Preview Changes

```bash
terraform plan
```

Review the plan. You should see ~9 resources to be created.

## Step 6: Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

Expected time: 30-60 seconds

## Step 7: Verify Outputs

```bash
terraform output
```

You should see:
- Source and destination bucket names
- IAM role ARNs
- Account IDs
- Replication status: "Enabled"

## Step 8: Test Replication

```bash
# Create test file
echo "Hello from source!" > test.txt

# Upload to source (replace with your values)
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 cp test.txt s3://my-source-bucket/test.txt

# Wait a few seconds
sleep 10

# Check destination
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://my-dest-bucket/test.txt
```

If you see the file, **congratulations!** 🎉 Replication is working!

## What Just Happened?

The module created:

1. ✅ Two S3 buckets (source and destination)
2. ✅ Enabled versioning on both buckets
3. ✅ Created IAM policies with CRR permissions
4. ✅ Created IAM roles for Backbeat service
5. ✅ Attached policies to roles
6. ✅ Configured replication from source to destination

## Next Steps

### Option 1: Customize Configuration

Edit `terraform.tfvars` to add:
- Custom policy/role names
- Tags for organization
- Prefix-based replication
- Different regions

Then run:
```bash
terraform plan
terraform apply
```

### Option 2: Use in Your Own Project

Create your own `main.tf`:

```hcl
# Define both providers with different aliases
# (Both use "aws" type for S3 compatibility, differentiated by alias)

provider "aws" {
  alias = "source"  # First provider for source endpoint
  # ... source configuration
}

provider "aws" {
  alias = "destination"  # Second provider for destination endpoint
  # ... destination configuration
}

# Use the module
module "my_crr_setup" {
  source = "../../Terraform/Modules/s3-crr"

  providers = {
    aws.source      = aws.source       # Maps to provider with alias="source"
    aws.destination = aws.destination  # Maps to provider with alias="destination"
  }

  source_bucket_name      = "my-bucket"
  destination_bucket_name = "my-bucket-replica"
  # ... other variables
}
```

### Option 3: Explore Documentation

- [README.md](../README.md) - Complete documentation
- [MIGRATION.md](../MIGRATION.md) - Migrating from bash script
- [TESTING.md](../TESTING.md) - Testing procedures
- [MODULE_STRUCTURE.md](../MODULE_STRUCTURE.md) - Module internals

## Common Issues

### Issue: "Error: Failed to get existing workspaces"

**Solution**: Backend configuration issue. For local state, just ignore.

### Issue: "Error: error configuring S3 Backend: no valid credential sources"

**Solution**: This is expected if you haven't configured a backend. Local state will be used.

### Issue: "Error creating S3 bucket: BucketAlreadyExists"

**Solution**: Set `create_source_bucket = false` and/or `create_destination_bucket = false`

### Issue: "Error: Error creating IAM policy: EntityAlreadyExists"

**Solution**: Set custom `policy_name` to avoid conflicts, or use existing resources.

### Issue: Replication not working

**Solution**:
1. Verify versioning: `aws s3api get-bucket-versioning --bucket <name>`
2. Check Backbeat service is running (Scality-specific)
3. Review IAM permissions
4. Check network connectivity between endpoints

## Cleanup

To remove all resources:

```bash
# First, empty the buckets if they have data
aws --profile source s3 rm s3://my-source-bucket/ --recursive
aws --profile destination s3 rm s3://my-dest-bucket/ --recursive

# Then destroy Terraform resources
terraform destroy
```

Type `yes` when prompted.

## Getting Help

1. Check [README.md](../README.md) for detailed documentation
2. Review [TESTING.md](../TESTING.md) for troubleshooting
3. Examine Terraform state: `terraform show`
4. Check Terraform plan: `terraform plan`
5. Review logs: Scality Backbeat logs for replication issues

## Comparison to Bash Script

**Old way (bash script):**
```bash
./enable_crr_api.bash \
  my-source-bucket source-profile \
  my-dest-bucket dest-profile \
  --create-bucket
```

**New way (Terraform):**
```bash
# One-time setup
terraform init

# Deploy
terraform apply

# Clean up
terraform destroy
```

**Benefits:**
- ✅ Version control your infrastructure
- ✅ See changes before applying (terraform plan)
- ✅ Automatic rollback on errors
- ✅ State tracking
- ✅ Idempotent operations
- ✅ Team collaboration

## Production Checklist

Before using in production:

- [ ] Review all variable values
- [ ] Set up remote state (S3 backend)
- [ ] Enable state locking
- [ ] Use separate workspaces (dev/staging/prod)
- [ ] Store secrets securely (not in tfvars)
- [ ] Set up CI/CD pipeline
- [ ] Configure monitoring/alerting
- [ ] Document runbooks
- [ ] Test disaster recovery
- [ ] Train team members

## Advanced Usage

### Use with Terraform Cloud

```hcl
terraform {
  backend "remote" {
    organization = "my-org"
    workspaces {
      name = "s3-crr-production"
    }
  }
}
```

### Use with Environment Variables

```bash
export TF_VAR_source_access_key="..."
export TF_VAR_source_secret_key="..."
export TF_VAR_destination_access_key="..."
export TF_VAR_destination_secret_key="..."

terraform apply
```

### Use with HashiCorp Vault

```hcl
data "vault_generic_secret" "source_creds" {
  path = "secret/scality/source"
}

module "s3_crr" {
  source_access_key = data.vault_generic_secret.source_creds.data["access_key"]
  source_secret_key = data.vault_generic_secret.source_creds.data["secret_key"]
  # ...
}
```

## Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Scality Documentation](https://documentation.scality.com/)
- [S3 Replication Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication.html)

## Support

For issues specific to this module:
- Check the documentation in the `docs/` folder
- Review existing issues
- Create a new issue with details

For Scality-specific issues:
- Consult Scality documentation
- Contact Scality support
- Check Scality community forums

---

**Time to complete**: ~5 minutes
**Difficulty**: Beginner
**Prerequisites**: Basic Terraform knowledge

Happy replicating! 🚀
