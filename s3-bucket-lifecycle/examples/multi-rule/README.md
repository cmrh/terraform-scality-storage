# Multi-Rule Lifecycle Example

This example demonstrates multiple lifecycle rules with different filter types:
- Prefix-based filtering (logs, backups, archives)
- Tag-based filtering (temporary files)
- Combined prefix + tag filtering (environment-specific backups)
- Rules that can be enabled/disabled

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

## Rules Configured

1. **expire-logs**: Delete logs after 30 days (prefix: `logs/`)
2. **expire-temp-files**: Delete temporary files after 7 days (tag: `Lifecycle=Temporary`)
3. **expire-dev-backups**: Delete dev backups after 14 days (prefix: `backups/` + tags)
4. **expire-prod-backups**: Delete production backups after 90 days (prefix: `backups/` + tags)
5. **abort-multipart**: Abort incomplete uploads after 3 days
6. **expire-archives**: Archive cleanup (disabled by default)

## Testing

Upload test files to see the rules in action:

```bash
# Logs (30-day retention)
aws s3 cp test.log s3://lifecycle-multi-rule-example/logs/

# Temporary files (7-day retention)
aws s3 cp temp.txt s3://lifecycle-multi-rule-example/ \
  --tagging "Lifecycle=Temporary"

# Dev backups (14-day retention)
aws s3 cp backup.tar.gz s3://lifecycle-multi-rule-example/backups/ \
  --tagging "Environment=dev&Type=backup"

# Production backups (90-day retention)
aws s3 cp backup.tar.gz s3://lifecycle-multi-rule-example/backups/ \
  --tagging "Environment=production&Type=backup"
```
