# Basic Example - S3 CRR Module

This example demonstrates the basic usage of the S3 Cross-Region Replication (CRR) module.

## Prerequisites

1. Two Scality RING/Zenko endpoints (or AWS S3 accounts)
2. Valid credentials for both source and destination
3. Terraform >= 1.0 installed

## Usage

### Option 1: Environment Variables (Recommended for Security) ✅

1. **Copy the environment variable template:**

   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your actual credentials:**

   ```bash
   vim .env  # or your preferred editor
   ```

   Update the credentials:
   ```bash
   export SCALITY_SOURCE_ACCESS_KEY="your-actual-key"
   export SCALITY_SOURCE_SECRET_KEY="your-actual-secret"
   export SCALITY_DESTINATION_ACCESS_KEY="your-actual-key"
   export SCALITY_DESTINATION_SECRET_KEY="your-actual-secret"
   ```

3. **Source the environment file:**

   ```bash
   source .env
   ```

4. **Verify variables are set:**

   ```bash
   echo $SCALITY_SOURCE_ACCESS_KEY  # Should print your key (first few chars)
   ```

5. **Initialize Terraform:**

   ```bash
   terraform init
   ```

6. **Review the execution plan:**

   ```bash
   terraform plan
   ```

   Terraform will automatically use the environment variables for credentials.

### Option 2: Terraform Variables (Alternative)

1. **Copy the example tfvars file:**

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your actual values:**

   ```bash
   vim terraform.tfvars  # or your preferred editor
   ```

   Update:
   - Source and destination endpoints
   - Access keys and secret keys
   - Bucket names
   - Regions
   - Tags

   **⚠️ Security Warning**: `terraform.tfvars` contains secrets and is in `.gitignore`. Never commit it!

3. **Initialize Terraform:**

   ```bash
   terraform init
   ```

4. **Review the execution plan:**

   ```bash
   terraform plan
   ```

   This will show you all the resources that will be created:
   - 2 S3 buckets (if `create_*_bucket = true`)
   - 2 IAM policies (source and destination)
   - 2 IAM roles (source and destination)
   - 2 Bucket versioning configurations
   - 1 Replication configuration

5. **Apply the configuration:**

   ```bash
   terraform apply
   ```

   Review the plan and type `yes` to proceed.

6. **View outputs:**

   ```bash
   terraform output
   ```

   This will display:
   - Bucket names and ARNs
   - IAM role and policy ARNs
   - Account IDs
   - Replication status
   - Complete summary

## Testing Replication

After applying the configuration, test that replication is working:

```bash
# Create a test file
echo "Hello from source bucket" > test.txt

# Upload to source bucket
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 cp test.txt s3://my-source-bucket/

# Wait a few seconds for replication
sleep 10

# Check if file appeared in destination
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://my-destination-bucket/

# Download from destination to verify
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 cp s3://my-destination-bucket/test.txt test-replicated.txt

# Compare
diff test.txt test-replicated.txt
```

## Cleanup

To remove all resources:

```bash
terraform destroy
```

**Warning**: This will:
- Remove the replication configuration
- Delete IAM policies and roles
- Optionally delete buckets (if created by Terraform)
- Data in buckets will be lost if buckets are deleted

## Customization

### Using Existing Buckets

If your buckets already exist:

```hcl
create_source_bucket      = false
create_destination_bucket = false
```

### Custom Policy/Role Names

To use specific names instead of auto-generated ones:

```hcl
policy_name = "my-company-crr-policy"
role_name   = "my-company-crr-role"
```

### Replicate Only Specific Prefix

To replicate only objects with a specific prefix:

```hcl
replication_prefix = "data/"  # Only replicate objects starting with "data/"
```

### Disable Replication (but keep configuration)

```hcl
replication_status = "Disabled"
```

## Expected Output

```
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

crr_summary = {
  "destination" = {
    "account_id" = "123456789012"
    "bucket" = "my-destination-bucket"
    "policy_arn" = "arn:aws:iam::123456789012:policy/crr-policy-20260113120000"
    "role_arn" = "arn:aws:iam::123456789012:role/crr-trust-role-20260113120000"
  }
  "replication" = {
    "prefix" = ""
    "status" = "Enabled"
  }
  "source" = {
    "account_id" = "098765432109"
    "bucket" = "my-source-bucket"
    "policy_arn" = "arn:aws:iam::098765432109:policy/crr-policy-20260113120000"
    "role_arn" = "arn:aws:iam::098765432109:role/crr-trust-role-20260113120000"
  }
}
destination_bucket_name = "my-destination-bucket"
destination_role_arn = "arn:aws:iam::123456789012:role/crr-trust-role-20260113120000"
replication_status = "Enabled"
source_bucket_name = "my-source-bucket"
source_role_arn = "arn:aws:iam::098765432109:role/crr-trust-role-20260113120000"
```

## Troubleshooting

### Issue: "Error creating S3 bucket"

- Check that endpoints are correct
- Verify credentials have permission to create buckets
- Ensure bucket names are globally unique (for AWS) or unique within your Scality namespace

### Issue: "Error calling STS GetCallerIdentity"

- Verify STS endpoint is configured correctly
- Check network connectivity to Scality endpoints
- If using Scality without STS support, set account IDs manually:

  ```hcl
  source_account_id      = "your-source-account-id"
  destination_account_id = "your-dest-account-id"
  ```

### Issue: "Replication not working"

1. Check versioning is enabled:
   ```bash
   aws --profile source s3api get-bucket-versioning --bucket my-source-bucket
   ```

2. Verify replication configuration:
   ```bash
   aws --profile source s3api get-bucket-replication --bucket my-source-bucket
   ```

3. Check Backbeat service logs (Scality-specific)

4. Verify IAM role permissions

## Next Steps

- Review the [module README](../../README.md) for advanced configuration
- Explore using Terraform workspaces for multiple environments
- Consider using remote state (S3 backend) for team collaboration
- Implement CI/CD pipeline for automated deployments
