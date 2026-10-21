# artesca-application-bucket

An ARTESCA bucket with versioning, default encryption, optional tags and an
optional expiration rule.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `artesca_bucket`: versioning enabled by default
- `artesca_bucket_encryption`: `AES256` by default
- `artesca_bucket_tagging`: when `tags` is set
- `artesca_bucket_workflow_expiration`: when `expiration_days` is set

## Prerequisites

- cmrh/artesca provider 1.1 or later.

## Usage

```hcl
module "bucket" {
  source  = "cmrh/storage/scality//modules/artesca-application-bucket"
  version = "~> 1.1"

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
| `versioning` | bool | `true` | Enable versioning. `false` leaves versioning unmanaged, so a new bucket stays unversioned. |
| `sse_algorithm` | string | `"AES256"` | `"AES256"`, or `null` for no default encryption. |
| `tags` | map(string) | `{}` | Bucket tags, up to 50. |
| `expiration_days` | number | `null` | Expire current versions this many days after creation. |
| `expiration_prefix` | string | `null` | Only expire keys with this prefix. |
| `force_destroy` | bool | `false` | Delete every object version on destroy. Apply before destroying. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name. |
| `bucket_arn` | Bucket ARN. |
| `versioning` | Whether versioning is enabled. |
| `expiration_rule_id` | Expiration rule ID, or null. |

## Caveats

- **Expiration covers current versions only.** On a versioned bucket it adds
  a delete marker and older versions remain. Rules for noncurrent versions
  and incomplete multipart uploads aren't available.
- **Destroy needs an empty bucket** unless `force_destroy = true` was applied
  first.
