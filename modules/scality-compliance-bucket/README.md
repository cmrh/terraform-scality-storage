# scality / compliance-bucket

Provisions a Scality S3 bucket with **Object Lock** enabled and a default
retention, so object versions written to it are locked for the retention
period. Suitable for audit logs, regulatory recordkeeping, immutable
backups, and other WORM workloads.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_bucket` with `object_lock_enabled = true` and `versioning = true`
- `scality_bucket_encryption` (SSE-S3 by default; SSE-KMS opt-in)
- `scality_bucket_object_lock` — default retention mode and period
- `scality_bucket_lifecycle` — abort incomplete multipart uploads (set
  `abort_incomplete_multipart_upload_days = null` to disable)

## Retention modes

You must explicitly choose `retention_mode`:

| Mode | Behavior |
|---|---|
| `GOVERNANCE` | A locked version can't be deleted, not even by the account root, unless the request sets `--bypass-governance-retention` (`x-amz-bypass-governance-retention`). |
| `COMPLIANCE` | Stricter: meant for regulatory WORM, where locks can't be bypassed. |

> Try `GOVERNANCE` first.

## Retention period

Set **exactly one** of `retention_days` or `retention_years`. The chosen
value is the bucket's *default* retention, applied to object versions written
to it.

## Recommended caller pattern

Pass operator credentials (output of `scality-account-operator`) as
`account_access_key` / `account_secret_key`. Reserve account-root
credentials for break-glass.

## Usage

### 7-year regulatory WORM

```hcl
module "audit_logs" {
  source  = "cmrh/storage/scality//modules/scality-compliance-bucket"
  version = "~> 1.2"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name     = "acme-audit-logs"
  retention_mode  = "COMPLIANCE"
  retention_years = 7

  tags = {
    application = "acme"
    purpose     = "audit-trail"
  }
}
```

### Governance mode — 90-day staging

```hcl
module "compliance_staging" {
  source  = "cmrh/storage/scality//modules/scality-compliance-bucket"
  version = "~> 1.2"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name    = "acme-compliance-staging"
  retention_mode = "GOVERNANCE"
  retention_days = 90
}
```

### Composing with `application-identity` for a write-only audit logger

```hcl
module "audit_logs" {
  source  = "cmrh/storage/scality//modules/scality-compliance-bucket"
  version = "~> 1.2"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name     = "acme-audit-logs"
  retention_mode  = "COMPLIANCE"
  retention_years = 7
}

# Audit writer — can write; locked versions stay until retention ends.
module "audit_writer" {
  source  = "cmrh/storage/scality//modules/scality-application-identity"
  version = "~> 1.2"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  username    = "audit-writer"
  bucket_arns = [module.audit_logs.bucket_arn]

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject"]
        Resource = "${module.audit_logs.bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = module.audit_logs.bucket_arn
      },
    ]
  })
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Caller credentials (operator recommended). |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `bucket_name` | string | (required) | Bucket name (3-63 chars). Forces replacement. |
| `tags` | map(string) | `{}` | Bucket tags. |
| `sse_algorithm` | string | `"AES256"` | `AES256` (SSE-S3) or `aws:kms`. |
| `kms_master_key_id` | string | `null` | KMS key ID; required when `sse_algorithm = "aws:kms"`. |
| `retention_mode` | string | (required) | `"GOVERNANCE"` or `"COMPLIANCE"`. |
| `retention_days` | number | `null` | Retention in days. Set this OR `retention_years` (exactly one). |
| `retention_years` | number | `null` | Retention in years. Set this OR `retention_days`. |
| `abort_incomplete_multipart_upload_days` | number | `7` | Days to retain incomplete MPUs. `null` disables this rule. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name. |
| `bucket_arn` | Bucket ARN — pass to `application-identity.bucket_arns`. |
| `retention_mode` | Configured retention mode. |
| `retention_period` | Default retention period (formatted as days or years). |
| `object_lock_enabled` | Always `true`. |

## Caveats

- **Object lock can only be enabled when the bucket is created.** Adding it
  to an existing bucket fails with `InvalidBucketState`. To put existing
  data under WORM, create a compliance bucket and copy the data in.
- **`COMPLIANCE` locks can't be lifted before retention ends,** not even by
  the account root, so a bucket holding such versions can't be destroyed
  until they expire. Choose it only when immutability is required.
- **Destroying a bucket that holds locked versions needs them deleted
  first;** with `GOVERNANCE`, delete them with the bypass header.
- **Lifecycle rules other than MPU abort are intentionally excluded,** so
  the module never expires versions. For post-retention cleanup, configure
  `scality_bucket_lifecycle` directly with ages longer than the retention
  period.
