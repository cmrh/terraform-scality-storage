# scality / ring-replication-target

A versioned RING bucket that an ARTESCA RING location replicates into, plus a
user whose key the location uses. The user can only do what replication
needs on that bucket.

Pair it with [`artesca/edge-replication`](../../artesca/edge-replication).

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_bucket`: the target bucket, versioned
- an IAM user with an access key (through `application-identity`) and an
  inline policy allowing `s3:GetBucketVersioning`, `s3:GetBucketLocation` and
  `s3:PutObject` on the bucket

## Prerequisites

- cmrh/scality provider 1.1.6 or later.

## Usage

```hcl
module "ring_target" {
  source  = "cmrh/storage/scality//modules/scality/ring-replication-target"
  version = "~> 1.0"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  bucket_name        = "edge-01-replica"
}
```

Pass `bucket_name`, `access_key` and `secret_key` to the ARTESCA location.
Use one target bucket per ARTESCA source bucket.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Key of a principal in the RING account, typically the operator from `account-operator`. |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `bucket_name` | string | (required) | Target bucket name. Forces replacement. |
| `username` | string | `"artesca-replication"` | Replication user's name. |
| `policy_name` | string | `"artesca-replication"` | Name of the user's inline policy. |
| `tags` | map(string) | `{}` | Tags on the bucket. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Target bucket name. |
| `bucket_arn` | Target bucket ARN. |
| `access_key` | Replication user's access key. |
| `secret_key` | Replication user's secret key (sensitive). |

## Caveats

- **Destroy needs an empty bucket.** The bucket is versioned, so delete every
  object version and delete marker before `terraform destroy`. See the
  [example](../../../examples/hybrid/artesca-edge-to-ring) for a command.
