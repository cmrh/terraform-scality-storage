# artesca-tiered-bucket

An ARTESCA bucket whose objects move to another location after a number of
days: a RING bucket (warm) or a Versity tape archive (cold).

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- the bucket, through `artesca-application-bucket`: versioned, `AES256` by
  default
- `artesca_bucket_workflow_transition`: moves current versions to
  `transition_location` after `transition_days`
- a second transition for noncurrent versions, when
  `noncurrent_transition_days` is set

## Prerequisites

- cmrh/artesca provider 1.2 or later.
- The target location, e.g. from `artesca-storage-location`.
- **RING target:** after the move the data lives only on RING. The location's
  key needs `s3:GetObject` and `s3:GetObjectVersion`, or reads through ARTESCA
  fail. Without delete rights, a permanent delete through ARTESCA leaves the
  data on RING. `scality-ring-replication-target` with `purpose = "tiering"`
  creates a key with both read and delete rights.
- **Cold target (`versity-tape`):** the location's endpoint must use TLS
  (`https://`). Setting up TLS is up to you: a certificate on the endpoint
  that ARTESCA trusts, or ARTESCA configured not to verify it.

## Usage

```hcl
module "bucket" {
  source  = "cmrh/storage/scality//modules/artesca-tiered-bucket"
  version = "~> 1.1"

  account_name        = module.account.account_name
  bucket_name         = "app-data"
  transition_location = module.location.name
  transition_days     = 30
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | (required) | Account that owns the bucket. Forces replacement. |
| `bucket_name` | string | (required) | Bucket name. Forces replacement. |
| `transition_location` | string | (required) | Location objects move to. |
| `transition_days` | number | (required) | Days after creation when objects become eligible to move. |
| `transition_prefix` | string | `null` | Only move keys with this prefix. |
| `noncurrent_transition_days` | number | `null` | Also move versions this many days after they become noncurrent. Must be lower than `noncurrent_version_expiration_days`. |
| `noncurrent_version_expiration_days` | number | `90` | Delete noncurrent versions after this many days. `null` keeps them. |
| `sse_algorithm` | string | `"AES256"` | `"AES256"`, or `null` for no default encryption. |
| `tags` | map(string) | `{}` | Bucket tags, up to 50. |
| `force_destroy` | bool | `false` | Delete every object version on destroy. Apply before destroying. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name. |
| `bucket_arn` | Bucket ARN. |
| `transition_rule_id` | Transition rule ID. |
| `noncurrent_transition_rule_id` | Noncurrent-version transition rule ID, or null. |

## Caveats

- **Objects move on ARTESCA's lifecycle schedule, not at an exact time.**
  `transition_days` makes an object eligible; even `0` doesn't move it
  immediately.
- **Only current versions move by default.** Set `noncurrent_transition_days`
  to move noncurrent versions too.
