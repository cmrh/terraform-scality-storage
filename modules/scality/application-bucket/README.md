# scality / application-bucket

Provisions a Scality S3 bucket with secure-by-default settings:
versioning on, SSE-S3 encryption, and lifecycle hygiene rules that clean
up orphaned multipart uploads and superseded object versions.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_bucket` — versioned bucket with tags
- `scality_bucket_encryption` — SSE-S3 by default; SSE-KMS opt-in
- `scality_bucket_lifecycle` — three baseline rules, each independently
  toggle-able by setting its `_days` variable to `null`:
  - Abort incomplete multipart uploads after `abort_incomplete_multipart_upload_days` (default 7)
  - Expire noncurrent versions after `noncurrent_version_expiration_days` (default 90)
  - Expire current objects after `expiration_days` (default null = retain forever)

If all three lifecycle variables are null, no `scality_bucket_lifecycle`
resource is created.

## Recommended caller pattern

Same as the rest of this repo: pass operator credentials (output of
`account-operator`) as `account_access_key` / `account_secret_key`.
Reserve account-root credentials for break-glass scenarios.

## Usage

### Standard application bucket

```hcl
module "acme_data" {
  source  = "cmrh/storage/scality//modules/scality/application-bucket"
  version = "~> 1.0"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name = "acme-data"
  tags = {
    application = "acme"
    environment = "production"
  }
}
```

### Logs bucket with 30-day expiration

```hcl
module "acme_logs" {
  source  = "cmrh/storage/scality//modules/scality/application-bucket"
  version = "~> 1.0"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name     = "acme-logs"
  expiration_days = 30
}
```

### Composing with `application-identity`

```hcl
module "acme_data" {
  source  = "cmrh/storage/scality//modules/scality/application-bucket"
  version = "~> 1.0"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name = "acme-data"
}

module "acme_app" {
  source  = "cmrh/storage/scality//modules/scality/application-identity"
  version = "~> 1.0"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  username    = "acme-app"
  bucket_arns = [module.acme_data.bucket_arn]
  # access_pattern defaults to "read-write"
}
```

### Disabling a lifecycle rule

```hcl
module "acme_archive" {
  source  = "cmrh/storage/scality//modules/scality/application-bucket"
  version = "~> 1.0"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  bucket_name = "acme-archive"

  # Keep all object versions forever
  noncurrent_version_expiration_days = null
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Caller credentials (operator recommended). |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `bucket_name` | string | (required) | Bucket name (3-63 chars). Forces replacement. |
| `versioning` | bool | `true` | Enable bucket versioning. |
| `tags` | map(string) | `{}` | Bucket tags. |
| `sse_algorithm` | string | `"AES256"` | `AES256` (SSE-S3) or `aws:kms`. |
| `kms_master_key_id` | string | `null` | KMS key ID; required when `sse_algorithm = "aws:kms"`. |
| `abort_incomplete_multipart_upload_days` | number | `7` | Days to retain incomplete MPUs. `null` disables this rule. |
| `noncurrent_version_expiration_days` | number | `90` | Days to retain superseded versions. `null` disables this rule. |
| `expiration_days` | number | `null` | Current object expiration. `null` retains indefinitely. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name. |
| `bucket_arn` | Bucket ARN — pass directly to `application-identity.bucket_arns`. |
| `versioning_enabled` | Whether versioning is enabled. |
| `lifecycle_rules` | Lifecycle rules applied to the bucket (for auditing). |

## Caveats

- **Access control is via IAM policies.** This module doesn't create a
  `scality_bucket_policy`. Grant access by attaching policies to users
  via `application-identity`. For bucket-level policies (e.g.,
  cross-account scenarios), use the `scality_bucket_policy` resource
  directly alongside this module.
- **Empty the bucket before `terraform destroy`.** Bucket contents
  (current objects, all noncurrent versions, and delete markers) are
  outside Terraform's lifecycle and need to be cleared manually.
- **For object lock / WORM compliance, use `compliance-bucket`.** Object
  lock is a creation-only setting on the bucket.
- **For more complex lifecycle rules** (multiple prefixes, condition
  filters), use `scality_bucket_lifecycle` directly. This module covers
  the common hygiene + single-prefix expiration cases.
