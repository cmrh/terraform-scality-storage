# scality / access-log-bucket

A bucket that receives server access logs, plus the logging configuration on
the source buckets that write to it.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_bucket`: the log bucket, unversioned
- `scality_bucket_policy`: lets the cluster's access-logging service user
  write log objects (`s3:PutObject`)
- `scality_bucket_encryption`: `AES256` by default
- `scality_bucket_lifecycle`: deletes log objects after `retention_days`
- `scality_bucket_logging`: one per entry in `logged_buckets`

## Prerequisites

- Server access logging enabled on the cluster.
- cmrh/scality provider 1.1.6 or later.

## Usage

```hcl
module "access_logs" {
  source  = "cmrh/storage/scality//modules/scality-access-log-bucket"
  version = "~> 1.2"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key

  bucket_name    = "app-logs"
  retention_days = 90

  logged_buckets = {
    "app-data"   = "app-data/"
    "app-images" = "app-images/"
  }
}
```

Adding or removing an entry in `logged_buckets` turns logging on or off for
that bucket.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Key of a principal in the account that owns the log bucket and the source buckets. |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `bucket_name` | string | (required) | Log bucket name. Forces replacement. |
| `retention_days` | number | `90` | Days after which log objects are deleted. Whole number, at least 1. |
| `logged_buckets` | map(string) | `{}` | Source bucket => key prefix in the log bucket. Same account only. Can't include `bucket_name`. |
| `log_delivery_principal` | string | `arn:aws:iam::000000000000:user/scality-internal/service-access-logging-user` | The cluster's access-logging service user. Override only if your cluster uses a different one. |
| `sse_algorithm` | string | `"AES256"` | `"AES256"`, `"aws:kms"`, or `null` to disable encryption. |
| `kms_master_key_id` | string | `null` | Required when `sse_algorithm = "aws:kms"`. |
| `tags` | map(string) | `{}` | Tags on the log bucket. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Log bucket name. |
| `bucket_arn` | Log bucket ARN, for `application-identity.bucket_arns`. |
| `logged_buckets` | Source buckets with logging enabled => prefix. |
| `retention_days` | Retention in days. |
| `policy` | Bucket policy applied to the log bucket. |

## Caveats

- **Delivery isn't immediate.** Log objects arrive several minutes after the
  requests they record.
- **Destroy needs an empty log bucket.** `terraform destroy` fails with
  `BucketNotEmpty` until the log objects are removed:

  ```sh
  aws --endpoint-url "$SCALITY_ENDPOINT" s3 rm --recursive "s3://<bucket_name>/"
  ```
