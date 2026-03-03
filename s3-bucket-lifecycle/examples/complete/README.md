# Complete Lifecycle Example

This example demonstrates all supported lifecycle features in a comprehensive configuration:

## Features Demonstrated

### Expiration Types
- **Days-based expiration**: Delete objects after N days
- **Date-based expiration**: Delete objects on a specific date
- **Expired delete marker cleanup**: Remove expired object delete markers

### Filtering Options
- **Prefix filtering**: Target objects by path prefix
- **Tag filtering**: Target objects by single tag
- **Combined filtering**: Prefix + multiple tags

### Version Management
- **Noncurrent version expiration**: Clean up old object versions
- **Delete marker cleanup**: Remove orphaned delete markers

### Multipart Upload Management
- **Abort incomplete uploads**: Clean up stale multipart uploads

## Usage

```bash
# Set credentials
export TF_VAR_s3_endpoint="https://s3.scality.example.com"
export TF_VAR_access_key="your-access-key"
export TF_VAR_secret_key="your-secret-key"

# Initialize
tofu init

# Plan with custom settings
tofu plan \
  -var="bucket_name=my-lifecycle-bucket" \
  -var="multipart_abort_days=3" \
  -var="enable_date_expiration=true"

# Apply
tofu apply

# View outputs
tofu output

# Cleanup
tofu destroy
```

## Configured Rules

| Rule ID | Filter Type | Action | Retention |
|---------|------------|--------|-----------|
| expire-by-days | Prefix: `data/` | Expiration | 365 days |
| expire-by-date | Prefix: `test-data/` | Expiration | 2026-12-31 |
| expire-old-versions | None | Noncurrent Expiration | 30 days |
| cleanup-delete-markers | None | Delete Markers | N/A |
| expire-tagged-temp | Tag: `Lifecycle=Temporary` | Expiration | 7 days |
| expire-dev-logs | Prefix: `logs/` + Tags | Expiration | 14 days |
| expire-prod-logs | Prefix: `logs/` + Tags | Expiration | 90 days |
| abort-multipart | None | Abort Multipart | 7 days |
| expire-cache | Prefix: `cache/` | Expiration | 1 day |

## Testing the Configuration

### 1. Upload test files

```bash
BUCKET="lifecycle-complete-example"
ENDPOINT="https://s3.scality.example.com"

# Regular data (365-day retention)
aws s3 cp file.txt s3://$BUCKET/data/ --endpoint-url=$ENDPOINT

# Test data (expires 2026-12-31)
aws s3 cp test.txt s3://$BUCKET/test-data/ --endpoint-url=$ENDPOINT

# Temporary file (7-day retention)
aws s3 cp temp.txt s3://$BUCKET/ \
  --tagging "Lifecycle=Temporary" \
  --endpoint-url=$ENDPOINT

# Dev logs (14-day retention)
aws s3 cp dev.log s3://$BUCKET/logs/ \
  --tagging "Environment=development&Type=log" \
  --endpoint-url=$ENDPOINT

# Production logs (90-day retention)
aws s3 cp prod.log s3://$BUCKET/logs/ \
  --tagging "Environment=production&Type=log" \
  --endpoint-url=$ENDPOINT

# Cache file (1-day retention)
aws s3 cp cache.dat s3://$BUCKET/cache/ --endpoint-url=$ENDPOINT
```

### 2. Verify lifecycle configuration

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket $BUCKET \
  --endpoint-url=$ENDPOINT
```

### 3. Test versioning

```bash
# Enable versioning (done by module)
# Upload a file
aws s3 cp version1.txt s3://$BUCKET/versioned-file.txt --endpoint-url=$ENDPOINT

# Upload a new version
aws s3 cp version2.txt s3://$BUCKET/versioned-file.txt --endpoint-url=$ENDPOINT

# List versions (old version will be cleaned up after 30 days)
aws s3api list-object-versions \
  --bucket $BUCKET \
  --endpoint-url=$ENDPOINT
```

## Customization

Modify variables to adjust behavior:

```hcl
# terraform.tfvars or .auto.tfvars
bucket_name              = "my-custom-bucket"
multipart_abort_days     = 3
enable_date_expiration   = true

tags = {
  Project     = "MyProject"
  Environment = "Production"
  CostCenter  = "Engineering"
}
```

## Outputs

The example provides comprehensive outputs:

- `bucket_id`: Bucket identifier
- `bucket_arn`: Bucket ARN
- `versioning_enabled`: Versioning status
- `lifecycle_configuration_id`: Lifecycle config ID
- `total_rules`: Number of rules
- `enabled_rules`: Active rule IDs
- `all_rules`: Complete rule configuration

## Notes

- **Versioning Required**: Noncurrent version expiration requires versioning to be enabled
- **Date Format**: Use ISO 8601 format for date-based expiration (YYYY-MM-DDTHH:MM:SSZ)
- **Tag Format**: Tags must be applied at upload time
- **Testing**: Lifecycle actions occur daily, so immediate results won't be visible
- **No Transitions**: Scality does not support transition policies (moving between storage classes)
