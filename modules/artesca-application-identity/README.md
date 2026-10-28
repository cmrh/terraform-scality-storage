# artesca-application-identity

An IAM user in an ARTESCA account, with an access key and an inline policy
scoped to specific buckets.

> Compatible with both Terraform and OpenTofu.

## What it creates

- `artesca_user`
- `artesca_user_access_key`
- `artesca_user_policy`: a preset over `bucket_arns`, or `policy_document`

## Access patterns (presets)

Each preset covers only the buckets in `bucket_arns`.

| `access_pattern` | Object actions | Bucket actions |
|---|---|---|
| `read-only` | `s3:GetObject`, `s3:GetObjectVersion` | `s3:ListBucket`, `s3:GetBucketLocation`, `s3:ListBucketVersions` |
| `read-write` (default) | `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject`, `s3:DeleteObject`, `s3:DeleteObjectVersion` | `s3:ListBucket`, `s3:GetBucketLocation`, `s3:ListBucketVersions` |
| `bucket-admin` | `s3:*` | `s3:*` |
## Prerequisites

- cmrh/artesca provider 1.1 or later.

## Usage

```hcl
module "app" {
  source  = "cmrh/storage/scality//modules/artesca-application-identity"
  version = "~> 1.2"

  account_name   = module.account.account_name
  username       = "app"
  access_pattern = "read-write"
  bucket_arns    = ["arn:aws:s3:::app-data"]
}
```

With a custom policy:

```hcl
module "reporter" {
  source  = "cmrh/storage/scality//modules/artesca-application-identity"
  version = "~> 1.2"

  account_name = module.account.account_name
  username     = "reporter"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::app-data/reports/*"]
    }]
  })
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | (required) | Account that owns the user. Forces replacement. |
| `username` | string | (required) | IAM username. Forces replacement. |
| `access_pattern` | string | `"read-write"` | `read-only`, `read-write` or `bucket-admin`. |
| `bucket_arns` | list(string) | `[]` | Buckets the preset covers. Required with a preset. |
| `policy_document` | string | `null` | Custom JSON policy; overrides the preset. |
| `policy_name` | string | `null` | Inline policy name. Defaults to `<username>-policy`. |
| `force_destroy` | bool | `false` | Detach policies and group memberships not managed here on destroy. Apply before destroying. |

## Outputs

| Name | Description |
|---|---|
| `username` | Username. |
| `user_id` | User ID. |
| `user_arn` | User ARN. |
| `access_key` | S3 access key (sensitive). |
| `secret_key` | S3 secret key (sensitive). |
| `policy_name` | Inline policy name. |
| `effective_policy` | Policy applied (preset or custom). |
