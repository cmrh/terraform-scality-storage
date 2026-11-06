# scality-application-identity

Creates a Scality IAM user with a stable access key and an inline policy
— the standard primitive for **per-application workload identity**. One
user per application or service, scoped to specific buckets.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_user` — the IAM user
- `scality_user_access_key` — S3 access key for the user
- `scality_user_policy` — the inline policy from the preset or
  `policy_document`, plus one per entry in `policies`
- `scality_iam_user_policy_attachment` — one per entry in `policy_arns`

## Access patterns (presets)

Three pre-canned policies cover the common cases. Each scopes access to
the buckets you specify in `bucket_arns` — never `*`.

| `access_pattern` | Object actions | Bucket actions | Use case |
|---|---|---|---|
| `read-only` | `s3:GetObject`, `s3:GetObjectVersion` | `s3:ListBucket`, `s3:GetBucketLocation`, `s3:ListBucketVersions` | Analytics, read-only consumers |
| `read-write` (default) | `s3:GetObject`, `s3:GetObjectVersion`, `s3:PutObject`, `s3:DeleteObject`, `s3:DeleteObjectVersion` | `s3:ListBucket`, `s3:GetBucketLocation`, `s3:ListBucketVersions` | Standard application workload |
| `bucket-admin` | `s3:*` (objects) | `s3:*` (buckets) | Tooling that needs to manage bucket configuration; rare for application workloads |

For anything more nuanced (multi-bucket with different permissions, IP
restrictions, condition keys, etc.), use the `policy_document` override
and write the JSON yourself.

## Recommended caller pattern

The `account_access_key` / `account_secret_key` inputs are credentials
for *any* account principal with sufficient IAM privileges
(`iam:CreateUser`, `iam:PutUserPolicy`, `iam:CreateAccessKey`,
`iam:DeleteUser`). Two valid sources:

| Source | When to use |
|---|---|
| **Operator user** (output of `account-operator` module) | **Recommended for production.** Long-lived, audit-friendly, rotatable independently of account-root credentials. |
| Account-root (output of `scality-account-management`) | One-shot deployments, dev sandboxes. Avoid for production — using account-root for day-to-day operations bypasses least-privilege. |

## Usage

### Read-write access to one bucket (default preset)

```hcl
module "acme_app" {
  source  = "cmrh/storage/scality//modules/scality-application-identity"
  version = "~> 1.4"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  username    = "acme-app"
  bucket_arns = ["arn:aws:s3:::acme-data"]
  # access_pattern defaults to "read-write"
}
```

### Read-only access to multiple buckets

```hcl
module "analytics_reader" {
  source  = "cmrh/storage/scality//modules/scality-application-identity"
  version = "~> 1.4"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  username       = "analytics-reader"
  access_pattern = "read-only"
  bucket_arns = [
    "arn:aws:s3:::acme-data",
    "arn:aws:s3:::acme-events",
  ]
}
```

### Custom policy (advanced — bypasses presets)

```hcl
module "acme_app_special" {
  source  = "cmrh/storage/scality//modules/scality-application-identity"
  version = "~> 1.4"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  username = "acme-special"

  # When set, access_pattern and bucket_arns are ignored.
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "arn:aws:s3:::acme-data/public/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "arn:aws:s3:::acme-data/uploads/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-server-side-encryption" = "AES256"
          }
        }
      },
    ]
  })
}
```

### Wiring credentials into an application

```bash
terraform output -raw acme_app_access_key  # → AWS_ACCESS_KEY_ID
terraform output -raw acme_app_secret_key  # → AWS_SECRET_ACCESS_KEY
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Caller credentials (operator recommended). |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `username` | string | (required) | IAM username. Forces replacement. |
| `access_pattern` | string | `"read-write"` | One of `read-only`, `read-write`, `bucket-admin`. |
| `bucket_arns` | list(string) | `[]` | ARNs of buckets the user gets access to. Required when using a preset. |
| `policy_document` | string | `null` | Custom JSON policy. Overrides `access_pattern` + `bucket_arns` when set. |
| `policy_name` | string | `null` | Inline policy name. Defaults to `<username>-policy`. |
| `policies` | map(string) | `{}` | Further inline policies: name => JSON document. Names can't repeat `policy_name`. |
| `policy_arns` | map(string) | `{}` | Managed policies to attach: static key => policy ARN. Reference the policy (`scality_iam_policy.x.arn`) so destroy detaches it first. |

> With no `bucket_arns`, `policy_document`, `policies` or `policy_arns`, the
> user has no policy.

## Outputs

| Name | Description | Sensitive |
|---|---|---|
| `username` | Created user's username. | No |
| `user_id` | Unique user identifier. | No |
| `user_arn` | User ARN (use in bucket policies referencing this principal). | No |
| `user_path` | IAM path. | No |
| `access_key` | User's S3 access key. | Yes |
| `secret_key` | User's S3 secret key. | Yes |
| `policy_name` | Name of the preset or `policy_document` policy; `null` when there is none. | No |
| `policy_names` | Names of every inline policy on the user. | No |
| `policy_arns` | ARNs of the managed policies attached to the user. | No |
| `effective_policy` | Rendered JSON of the preset or `policy_document` policy; `null` when there is none. | No |

## Caveats

- **Username and policy name changes force replacement.** `policy_document` updates apply
  in-place; toggling between a preset and a custom document also applies
  in-place since only the policy content changes.
- **Secret key is one-time.** The Scality IAM API does not return secret
  keys on read. If you lose state, the access key must be rotated to a
  new pair (re-create the resource).
- **Don't reuse this user's keys for bucket management.** The application
  user is meant for workload data access, not infrastructure operations.
  The recommended pattern is to use **operator** creds for
  bucket management and **application-identity** creds only for
  application workload access.
- **Protect your state file.** Contains the user's secret key in plain
  text.
