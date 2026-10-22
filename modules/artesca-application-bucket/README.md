# artesca-application-bucket

An ARTESCA bucket with versioning, default encryption, lifecycle cleanup,
optional tags and an optional expiration rule.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `artesca_bucket`: versioning enabled by default
- `artesca_bucket_encryption`: `AES256` by default
- `artesca_bucket_tagging`: when `tags` is set
- `artesca_bucket_workflow_expiration` (cleanup): deletes noncurrent versions
  after 90 days and aborts incomplete multipart uploads after 7 days by
  default; optionally removes leftover delete markers
- `artesca_bucket_workflow_expiration` (expiration): when `expiration_days` is
  set

## Prerequisites

- cmrh/artesca provider 1.2 or later.

## Usage

```hcl
module "bucket" {
  source  = "cmrh/storage/scality//modules/artesca-application-bucket"
  version = "~> 1.2"

  account_name    = module.account.account_name
  bucket_name     = "app-data"
  tags            = { team = "platform" }
  expiration_days = 30
}
```

Grant access with `artesca-application-identity`, passing
`module.bucket.bucket_arn` in `bucket_arns`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | (required) | Account that owns the bucket. Forces replacement. |
| `bucket_name` | string | (required) | Bucket name. Forces replacement. |
| `location_constraint` | string | `null` | ARTESCA location for the bucket's data. Null uses ARTESCA's own storage. Forces replacement. |
| `object_lock_enabled` | bool | `false` | Create the bucket with object lock (needs `versioning = true`). See caveats. |
| `versioning` | bool | `true` | Enable versioning. `false` leaves versioning unmanaged, so a new bucket stays unversioned. |
| `sse_algorithm` | string | `"AES256"` | `"AES256"`, or `null` for no default encryption. |
| `tags` | map(string) | `{}` | Bucket tags, up to 50. |
| `expiration_days` | number | `null` | Expire current versions this many days after creation. |
| `expiration_prefix` | string | `null` | Only expire keys with this prefix. |
| `noncurrent_version_expiration_days` | number | `90` | Delete versions this many days after they become noncurrent. `null` disables. |
| `abort_incomplete_multipart_upload_days` | number | `7` | Abort incomplete multipart uploads after this many days. `null` disables. |
| `expire_delete_markers` | bool | `false` | Remove delete markers with no noncurrent versions left behind them. |
| `force_destroy` | bool | `false` | Delete every object version on destroy. Apply before destroying. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name. |
| `bucket_arn` | Bucket ARN. |
| `versioning` | Whether versioning is enabled. |
| `cleanup_rule_id` | Cleanup rule ID, or null. |
| `expiration_rule_id` | Expiration rule ID, or null. |

## Caveats

- **Turning `object_lock_enabled` on for an existing bucket replaces it.** Run
  `apply` a second time afterwards: the replacement drops the bucket's
  encryption and lifecycle rules, and the second apply recreates them.
  Setting it back to `false` leaves object lock on.
- **Destroy fails on a bucket that still holds objects** (`Bucket not
  empty`), unless `force_destroy = true` was applied first.
