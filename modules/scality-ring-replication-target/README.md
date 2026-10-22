# scality-ring-replication-target

A versioned RING bucket that an ARTESCA RING location writes into, plus a user
whose key the location uses. The key can only do what its `purpose` needs:
replication (`artesca-edge-replication`: `replication` for its `ring-s3`
mode, `crr` for its `crr` mode), or tiering and RING-backed buckets.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_bucket`: the target bucket, versioned
- an IAM user with an access key (through `application-identity`) and an
  inline policy on the bucket, set by `purpose`:
  - `replication` (default): `s3:GetBucketVersioning`, `s3:GetBucketLocation`,
    `s3:PutObject`
  - `tiering`: the same, plus `s3:GetObject`, `s3:GetObjectVersion`,
    `s3:DeleteObject`, `s3:DeleteObjectVersion`. Use it when the data lives
    only on RING: a tiered bucket (`artesca-tiered-bucket`) or a bucket stored
    on the location (`examples/artesca-ring-backed-bucket`). Reads through
    ARTESCA fail without the read actions. With the delete actions, a
    permanent delete through ARTESCA removes the object from RING; without
    them, the data stays there.
  - `crr`: only `sts:AssumeRole` on a destination role, for
    `artesca-edge-replication` with `mode = "crr"`
- for `crr`: a destination role (`role_name`) that trusts only that user and
  can `s3:ReplicateObject`, `s3:ReplicateDelete` and `s3:ReplicateTags` on
  the bucket

## Prerequisites

- cmrh/scality provider 1.1.6 or later.

## Usage

```hcl
module "ring_target" {
  source  = "cmrh/storage/scality//modules/scality-ring-replication-target"
  version = "~> 1.2"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  bucket_name        = "edge-01-replica"
}
```

Pass `bucket_name`, `access_key` and `secret_key` to the ARTESCA location,
and `role_arn` too for `crr`.
Use one target bucket per ARTESCA source bucket.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Key of a principal in the RING account, typically the operator from `account-operator`. |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `bucket_name` | string | (required) | Target bucket name. Forces replacement. |
| `purpose` | string | `"replication"` | `replication`, `tiering` or `crr`; sets the key's permissions. |
| `role_name` | string | `"artesca-crr"` | Destination role name, for `crr`. |
| `username` | string | `"artesca-replication"` | Replication user's name. |
| `policy_name` | string | `"artesca-replication"` | Name of the user's inline policy. |
| `tags` | map(string) | `{}` | Tags on the bucket. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Target bucket name. |
| `bucket_arn` | Target bucket ARN. |
| `role_arn` | Destination role ARN for `crr`, or null. |
| `access_key` | Replication user's access key. |
| `secret_key` | Replication user's secret key (sensitive). |

## Caveats

- **Destroy needs an empty bucket.** The bucket is versioned, so delete every
  object version and delete marker before `terraform destroy`. See the
  [example](../../examples/artesca-edge-to-ring) for a command.
