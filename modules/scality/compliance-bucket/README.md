# scality / compliance-bucket

Provisions a Scality S3 bucket with **Object Lock** enabled — objects
written to this bucket cannot be deleted or overwritten until their
retention period expires. Suitable for audit logs, regulatory
recordkeeping, immutable backups, and other WORM workloads.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_bucket` with `object_lock_enabled = true` (versioning is
  automatically enabled by S3 when object lock is set)
- `scality_bucket_encryption` (SSE-S3 by default; SSE-KMS opt-in)
- `scality_bucket_object_lock` — default retention mode and period
- `scality_bucket_lifecycle` — abort incomplete multipart uploads (set
  `abort_incomplete_multipart_upload_days = null` to disable)

## Retention modes

You must explicitly choose `retention_mode`:

| Mode | Behavior |
|---|---|
| `GOVERNANCE` | Users with `s3:BypassGovernanceRetention` permission can override or delete locks. Suitable for testing, staging, or workflows where regulated overrides are acceptable. |
| `COMPLIANCE` | No one — including the account root — can override or delete locks. Objects are immutable until their retention period expires. Suitable for regulatory WORM (audit logs, financial records, etc.). |

> `COMPLIANCE` is irrevocable for the duration of an object's retention
> period. Test retention behavior in `GOVERNANCE` mode first if you are
> not certain. Changing the mode after objects are written affects only
> future objects.

## Retention period

Set **exactly one** of `retention_days` or `retention_years`. The chosen
value applies to every new object written to the bucket as the *default*
retention. Per-object overrides remain possible through the S3 API.

## Recommended caller pattern

Same as the rest of this repo: pass operator credentials (output of
`account-operator`) as `account_access_key` / `account_secret_key`.

## Usage

### 7-year regulatory WORM

```hcl
module "audit_logs" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/compliance-bucket?ref=v0.1.0"

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
  source = "...//modules/scality/compliance-bucket?ref=v0.1.0"

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
  source = "...//modules/scality/compliance-bucket?ref=v0.1.0"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name     = "acme-audit-logs"
  retention_mode  = "COMPLIANCE"
  retention_years = 7
}

# Audit writer — IAM allows write but the COMPLIANCE lock prevents
# deletes during retention regardless of IAM permissions.
module "audit_writer" {
  source = "...//modules/scality/application-identity?ref=v0.1.0"

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

- **Object lock is set at bucket creation only.** This module enables it
  at creation. To put an existing non-lock-enabled bucket under WORM,
  create a new compliance bucket and migrate the contents.
- **`COMPLIANCE` retention is irrevocable.** Even the account root cannot
  delete objects within their retention period. Choose this only when
  regulatory or contractual immutability is required.
- **Bucket destruction is blocked while objects are under active
  retention.** With `COMPLIANCE`, the bucket cannot be destroyed until
  every retained object has aged past its retention date.
- **Default retention applies to new objects only.** Existing objects
  retain their original lock state if the retention configuration is
  changed later.
- **Lifecycle rules other than MPU abort are intentionally excluded.**
  Expiring noncurrent versions or current objects via lifecycle would
  conflict with object lock semantics. If you need post-retention
  cleanup, configure `scality_bucket_lifecycle` directly with rules
  scoped to ages that exceed the retention period.
