# artesca-compliance-bucket

An ARTESCA bucket with object lock and a default retention, for records that
must not be deleted or changed for a set period.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- the bucket, through `artesca-application-bucket`: object lock (which keeps
  versioning on), `AES256` by default, incomplete multipart uploads aborted
  after 7 days. Noncurrent versions aren't expired.
- `artesca_bucket_object_lock`: the default retention applied to new object
  versions

## Prerequisites

- cmrh/artesca provider 1.2 or later.

## Usage

```hcl
module "records" {
  source  = "cmrh/storage/scality//modules/artesca-compliance-bucket"
  version = "~> 1.2"

  account_name   = module.account.account_name
  bucket_name    = "records"
  retention_mode = "COMPLIANCE"
  retention_years = 7
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | (required) | Account that owns the bucket. Forces replacement. |
| `bucket_name` | string | (required) | Bucket name. Forces replacement. |
| `retention_mode` | string | (required) | `GOVERNANCE` or `COMPLIANCE`. |
| `retention_days` | number | `null` | Default retention in days. Set exactly one of days or years. |
| `retention_years` | number | `null` | Default retention in years. |
| `sse_algorithm` | string | `"AES256"` | `"AES256"`, or `null` for no default encryption. |
| `tags` | map(string) | `{}` | Bucket tags, up to 50. |
| `abort_incomplete_multipart_upload_days` | number | `7` | Abort incomplete multipart uploads after this many days. `null` disables. |
| `force_destroy` | bool | `false` | Delete every version on destroy where retention allows. Apply before destroying. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name. |
| `bucket_arn` | Bucket ARN. |
| `retention_mode` | Default retention mode. |
| `retention_period` | Default retention period. |

## Caveats

- **`COMPLIANCE` versions can't be deleted until their retention ends,** not
  even by the account root or with `--bypass-governance-retention`. With
  `force_destroy`, `terraform destroy` stops with an error naming the locked
  version and its retain-until date; the account and bucket remain. Try
  `GOVERNANCE` first.
- **A blocked destroy has already removed the default retention.** New
  versions aren't locked until you apply again.
- **Destroy with locked `GOVERNANCE` versions** needs `force_destroy = true`
  applied first.
