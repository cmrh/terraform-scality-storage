# artesca / edge-replication

An ARTESCA account with a versioned bucket on ARTESCA's default storage,
replicated to a RING bucket. Optionally creates IAM users with keys that can
read and write the bucket.

Pair it with
[`scality-ring-replication-target`](../scality-ring-replication-target),
which creates the RING bucket and the key the location uses.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `artesca_account`
- `artesca_bucket`: versioned, on the default location (`us-east-1`)
- `artesca_user`, `artesca_user_policy`, `artesca_user_access_key`: one set
  per entry in `users`
- `artesca_location`: type `location-scality-ring-s3-v1`, with
  `bucket_match = true`, so objects keep their keys at the root of the RING
  bucket
- `artesca_bucket_workflow_replication`: replicates the bucket to the location

## Prerequisites

- cmrh/artesca provider 1.1 or later.
- ARTESCA can reach the RING S3 endpoint. Prefer `https://`: the location's
  key and every replicated object pass through it.
- A RING bucket and key that the location can use, from
  `ring-replication-target`.

## Usage

```hcl
module "edge" {
  source  = "cmrh/storage/scality//modules/artesca-edge-replication"
  version = "~> 1.0"

  account_name  = "edge-01"
  account_email = "edge-01@example.com"
  bucket_name   = "edge-01-data"
  users         = ["edge-01-app"]

  location_name    = "edge-01-ring"
  ring_endpoint    = "https://s3.ring.example.com"
  ring_bucket_name = module.ring_target.bucket_name
  ring_access_key  = module.ring_target.access_key
  ring_secret_key  = module.ring_target.secret_key
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | (required) | ARTESCA account name. Forces replacement. |
| `account_email` | string | (required) | Account email. Forces replacement. |
| `bucket_name` | string | (required) | Source bucket. Forces replacement. |
| `users` | set(string) | `[]` | IAM users to create, each with a key and read-write access to the bucket. |
| `location_name` | string | (required) | RING location name. Locations are instance-wide, so make it unique. |
| `ring_endpoint` | string | (required) | RING S3 endpoint URL. |
| `ring_bucket_name` | string | (required) | RING target bucket. |
| `ring_access_key` | string (sensitive) | (required) | RING key the location uses. |
| `ring_secret_key` | string (sensitive) | (required) | Paired with `ring_access_key`. |
| `replication_enabled` | bool | `true` | Whether the replication rule is active. |
| `force_destroy` | bool | `false` | Lets destroy delete the bucket's objects and the users' policies. Set it and apply before destroying. |

## Outputs

| Name | Description |
|---|---|
| `account_name` | ARTESCA account name. |
| `account_id` | ARTESCA account ID. |
| `bucket_name` | Source bucket name. |
| `location_name` | RING location name. |
| `replication_rule_id` | Replication rule ID (the workflow ID in the ARTESCA UI). |
| `user_access_keys` | Access key and secret key per user (sensitive). |

## Caveats

- **Changing the RING key updates the location in place.**
- **Destroy:** set `force_destroy = true` and apply first. The RING bucket
  is managed separately and must be emptied before it can be deleted.
