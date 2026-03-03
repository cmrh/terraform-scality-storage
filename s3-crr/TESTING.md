# Testing Guide

This guide provides instructions for validating the Terraform S3 CRR module.

## Pre-Deployment Testing

### 1. Validate Terraform Syntax

```bash
cd terraform-s3-crr-module
terraform fmt -check -recursive
terraform validate
```

### 2. Check for Common Issues

```bash
# Install tflint (optional but recommended)
# https://github.com/terraform-linters/tflint

tflint --init
tflint
```

### 3. Validate Provider Configuration

Before running the module, test that providers can connect:

```bash
# Test source endpoint
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 ls

# Test destination endpoint
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls
```

## Deployment Testing

### 1. Plan Phase

```bash
cd examples/basic
terraform init
terraform plan -out=tfplan

# Review the plan carefully
terraform show tfplan
```

Expected resources in plan:
- 2 S3 buckets (if `create_*_bucket = true`)
- 2 IAM policies
- 2 IAM roles
- 2 Role-policy attachments
- 2 Bucket versioning configurations
- 1 Replication configuration

**Total: ~9 resources**

### 2. Apply Phase

```bash
terraform apply tfplan
```

Monitor for:
- All resources created successfully
- No errors in output
- Outputs display correctly

### 3. Verify State

```bash
terraform state list
```

Expected state resources:
```
module.s3_crr.data.aws_caller_identity.destination
module.s3_crr.data.aws_caller_identity.source
module.s3_crr.aws_iam_policy.destination_crr
module.s3_crr.aws_iam_policy.source_crr
module.s3_crr.aws_iam_role.destination_crr
module.s3_crr.aws_iam_role.source_crr
module.s3_crr.aws_iam_role_policy_attachment.destination_crr
module.s3_crr.aws_iam_role_policy_attachment.source_crr
module.s3_crr.aws_s3_bucket.destination[0]
module.s3_crr.aws_s3_bucket.source[0]
module.s3_crr.aws_s3_bucket_replication_configuration.source
module.s3_crr.aws_s3_bucket_versioning.destination
module.s3_crr.aws_s3_bucket_versioning.source
```

## Post-Deployment Testing

### 1. Verify IAM Resources

```bash
# Check source IAM policy
aws --profile source \
    --endpoint-url https://source.scality.local \
    iam get-policy --policy-arn <source_policy_arn>

# Check source IAM role
aws --profile source \
    --endpoint-url https://source.scality.local \
    iam get-role --role-name <role_name>

# Repeat for destination
```

### 2. Verify S3 Bucket Configuration

```bash
# Check source bucket exists
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3api head-bucket --bucket <source-bucket-name>

# Check versioning is enabled
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3api get-bucket-versioning --bucket <source-bucket-name>

# Expected output:
# {
#     "Status": "Enabled"
# }

# Check replication configuration
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3api get-bucket-replication --bucket <source-bucket-name>

# Repeat for destination bucket
```

### 3. Test Replication Functionality

#### Test 1: Basic Object Replication

```bash
# Create test file
echo "Test content $(date)" > test-file.txt

# Upload to source
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 cp test-file.txt s3://<source-bucket-name>/test-file.txt

# Wait for replication (typically a few seconds)
sleep 10

# Check if replicated to destination
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://<destination-bucket-name>/test-file.txt

# Download from destination
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 cp s3://<destination-bucket-name>/test-file.txt test-file-replicated.txt

# Compare files
diff test-file.txt test-file-replicated.txt
# Should show no differences
```

#### Test 2: Multiple Objects

```bash
# Create multiple test files
for i in {1..10}; do
  echo "Test file $i content" > test-$i.txt
done

# Upload all files
for i in {1..10}; do
  aws --profile source \
      --endpoint-url https://source.scality.local \
      s3 cp test-$i.txt s3://<source-bucket-name>/test-$i.txt
done

# Wait for replication
sleep 15

# Check destination
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://<destination-bucket-name>/

# Count files
SOURCE_COUNT=$(aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 ls s3://<source-bucket-name>/ | wc -l)

DEST_COUNT=$(aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://<destination-bucket-name>/ | wc -l)

echo "Source count: $SOURCE_COUNT"
echo "Destination count: $DEST_COUNT"
```

#### Test 3: Object Deletion Replication

```bash
# Delete an object from source
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 rm s3://<source-bucket-name>/test-file.txt

# Wait for delete replication
sleep 10

# Verify deletion replicated
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://<destination-bucket-name>/test-file.txt
# Should return nothing or error
```

#### Test 4: Large File Replication

```bash
# Create a large file (100MB)
dd if=/dev/urandom of=large-file.bin bs=1M count=100

# Upload to source
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 cp large-file.bin s3://<source-bucket-name>/large-file.bin

# Monitor replication
watch -n 5 'aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://<destination-bucket-name>/large-file.bin'
```

#### Test 5: Prefix-Based Replication (if configured)

If `replication_prefix` is set (e.g., `"data/"`):

```bash
# Create files with matching prefix
echo "Should replicate" > data-file.txt
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 cp data-file.txt s3://<source-bucket-name>/data/file.txt

# Create files without matching prefix
echo "Should NOT replicate" > other-file.txt
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 cp other-file.txt s3://<source-bucket-name>/other/file.txt

# Wait and verify
sleep 10

# Check destination - should only have data/ prefix files
aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 ls s3://<destination-bucket-name>/ --recursive
```

### 4. Verify Replication Metrics (Scality-specific)

If using Scality with Backbeat metrics:

```bash
# Check Backbeat metrics endpoint
curl http://backbeat-endpoint:8900/_/metrics

# Look for CRR-related metrics
curl http://backbeat-endpoint:8900/_/metrics | grep -i replication
```

## Idempotency Testing

### Test 1: Re-apply Configuration

```bash
# Apply again with no changes
terraform apply

# Expected output: "No changes. Your infrastructure matches the configuration."
```

### Test 2: Modify and Re-apply

```bash
# Modify a tag
# In terraform.tfvars, change:
# tags = { Environment = "staging" }

terraform plan
# Should show only tag updates

terraform apply
```

### Test 3: Destroy and Recreate

```bash
# Destroy all resources
terraform destroy

# Recreate
terraform apply

# Verify all tests pass again
```

## Failure Scenarios

### Test 1: Invalid Credentials

```bash
# Temporarily set invalid credentials in terraform.tfvars
terraform apply
# Should fail with authentication error
```

### Test 2: Invalid Endpoint

```bash
# Set invalid endpoint
source_endpoint = "https://invalid.endpoint.local"

terraform apply
# Should fail with connection error
```

### Test 3: Duplicate Resource Names

```bash
# Try to create with existing policy/role names
terraform apply
# Should handle gracefully or fail with clear error
```

## Performance Testing

### Replication Latency Test

```bash
#!/bin/bash
# test-replication-latency.sh

BUCKET_SRC="<source-bucket-name>"
BUCKET_DST="<destination-bucket-name>"
ENDPOINT_SRC="https://source.scality.local"
ENDPOINT_DST="https://destination.scality.local"

for i in {1..100}; do
  FILENAME="perf-test-$i.txt"
  echo "Test $i" > $FILENAME

  START=$(date +%s)

  # Upload to source
  aws --profile source --endpoint-url $ENDPOINT_SRC \
      s3 cp $FILENAME s3://$BUCKET_SRC/$FILENAME

  # Wait for replication
  while true; do
    aws --profile destination --endpoint-url $ENDPOINT_DST \
        s3 ls s3://$BUCKET_DST/$FILENAME &>/dev/null

    if [ $? -eq 0 ]; then
      END=$(date +%s)
      DURATION=$((END - START))
      echo "File $i replicated in $DURATION seconds"
      break
    fi

    sleep 1
  done

  rm $FILENAME
done
```

## Cleanup After Testing

```bash
# Remove test files from buckets
aws --profile source \
    --endpoint-url https://source.scality.local \
    s3 rm s3://<source-bucket-name>/ --recursive

aws --profile destination \
    --endpoint-url https://destination.scality.local \
    s3 rm s3://<destination-bucket-name>/ --recursive

# Destroy Terraform resources
terraform destroy
```

## Automated Testing

### Using Terratest (Go)

Create `test/crr_test.go`:

```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestCRRModule(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/basic",
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Verify outputs
    sourceBucket := terraform.Output(t, terraformOptions, "source_bucket_name")
    assert.NotEmpty(t, sourceBucket)
}
```

## Test Checklist

Before production deployment:

- [ ] Terraform syntax validation passes
- [ ] Terraform plan shows expected resources
- [ ] All resources created successfully
- [ ] Source bucket versioning enabled
- [ ] Destination bucket versioning enabled
- [ ] IAM policies created with correct permissions
- [ ] IAM roles created with correct trust relationships
- [ ] Replication configuration applied
- [ ] Test file replicates successfully
- [ ] Multiple files replicate successfully
- [ ] Large files replicate successfully
- [ ] Delete operations replicate
- [ ] Prefix filtering works (if configured)
- [ ] Idempotency verified (re-apply works)
- [ ] Destroy and recreate works
- [ ] Documentation is accurate
- [ ] Team trained on usage

## Troubleshooting Common Test Failures

### Replication not working

1. Check Backbeat service status
2. Verify IAM permissions
3. Check bucket policies
4. Review Backbeat logs
5. Verify network connectivity

### Terraform apply fails

1. Check credentials are valid
2. Verify endpoints are reachable
3. Ensure account IDs are correct
4. Check for resource naming conflicts

### Performance issues

1. Check Backbeat capacity
2. Verify network bandwidth
3. Review object sizes
4. Check concurrent operations limit

## Next Steps

After successful testing:
1. Document any environment-specific configurations
2. Create runbooks for common operations
3. Set up monitoring and alerting
4. Implement backup procedures
5. Train operations team
