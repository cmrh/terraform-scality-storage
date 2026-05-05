# scality / terraform-state-bootstrap

Provisions a dedicated Scality account and S3 bucket suitable for storing
Terraform/OpenTofu state files.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu — commands, syntax,
> and state files are identical.

## What it creates

- A dedicated `scality_account` for blast-radius isolation
- A stable `scality_account_access_key` that Terraform owns exclusively
- A versioned `scality_bucket` (versioning is mandatory)
- `scality_bucket_encryption` (SSE-S3 by default)
- `scality_bucket_lifecycle` rules:
  - Abort incomplete multipart uploads after `abort_incomplete_multipart_upload_days` (default 7)
  - Expire noncurrent versions after `noncurrent_version_expiration_days` (default 90)

## Usage

This module bootstraps the state backend, so it must run with **local
state** the first time. Pin the provider, configure the admin endpoint via
environment variables, and apply:

```bash
export SCALITY_ENDPOINT="https://your-scality-endpoint"
export SCALITY_ACCESS_KEY="admin-access-key"
export SCALITY_SECRET_KEY="admin-secret-key"
```

```hcl
terraform {
  required_providers {
    scality = {
      source  = "scality/scality"
      version = "~> 0.4"
    }
  }
}

provider "scality" {}

module "tf_state" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/terraform-state-bootstrap?ref=v0.1.0"

  account_email = "platform@example.com"
  bucket_name   = "platform-tf-state"
}

output "state_bucket"     { value = module.tf_state.bucket_name }
output "state_access_key" { value = module.tf_state.access_key, sensitive = true }
output "state_secret_key" { value = module.tf_state.secret_key, sensitive = true }
```

```bash
terraform init
terraform apply
```

Capture the outputs (`terraform output -raw <name>`) for the downstream
backend configuration below.

## Configuring downstream projects

In every downstream project that should store state in this bucket:

```hcl
terraform {
  backend "s3" {
    bucket = "platform-tf-state"       # output: bucket_name
    key    = "PROJECT/STATE.tfstate"   # one path per project
    region = "us-east-1"

    endpoints = {
      s3 = "https://your-scality-endpoint"
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true

    # State locking — see "State Locking" below.
    # use_lockfile = false
  }
}
```

Pass the credentials via environment variables (recommended) so they never
land in version control:

```bash
export AWS_ACCESS_KEY_ID="$(terraform output -raw state_access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform output -raw state_secret_key)"

terraform init
```

## State Locking

> **Important:** Scality S3C does not currently support conditional
> `PutObject` writes (`If-None-Match: *`). The native S3 lockfile feature
> (`use_lockfile = true`, available in Terraform 1.10+ / OpenTofu 1.10+)
> relies on this header to atomically acquire a lock object. On Scality
> the lock is silently overwritten, so concurrent `apply` operations
> cannot be safely serialized.

Object versioning preserves prior state file content for recovery, but it
does **not** prevent concurrent writes. Two simultaneous `apply`s would
both make real infrastructure changes, the second would overwrite the
first's state, and the first's changes would be orphaned (real, but absent
from state).

### Default — single-operator workflow

Run `terraform apply` from one machine, by one operator at a time. Leave
`use_lockfile` unset (or `false`) in the downstream backend block. This is
the supported and tested usage pattern for this module.

If two state versions ever land in the bucket within seconds of each other,
treat it as a near-miss: investigate before further applies, restore from
versioning if needed.

### Exception — multi-operator / team workflow

If multiple operators or CI pipelines must apply against the same state
concurrently, use a backend with native locking instead:

| Backend | Locking | Tradeoff |
|---|---|---|
| [`pg`](https://opentofu.org/docs/language/settings/backends/pg/) | Postgres advisory lock | Adds a Postgres dependency outside Scality |
| [`http`](https://opentofu.org/docs/language/settings/backends/http/) with a lock-aware server | Server-side locks | Adds a custom server outside Scality |
| Terraform Cloud / Scalr / Spacelift / etc. | Built into the platform | Commercial / hosted |

This module does not provision any of these alternative backends — they
are the customer's responsibility. The state bucket created here can still
serve as a read-only snapshot store alongside one of them, but it is not
the primary state store in this path.

When Scality S3C ships conditional-write support, set `use_lockfile = true`
in the downstream backend block and the single-operator constraint goes
away — no module change needed.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | `"terraform-state"` | Dedicated account name (1-128 chars, alphanumeric + hyphens). |
| `account_email` | string | (required) | Email registered against the dedicated account. |
| `account_attributes` | map(string) | `{ managed_by = "terraform", purpose = "state-file" }` | Custom attributes applied to the account. Same purpose as `tags` for buckets. Max 10 attributes per account. |
| `bucket_name` | string | (required) | State bucket name (3-63 chars, lowercase + digits + hyphens + periods). |
| `tags` | map(string) | `{ managed_by = "terraform", purpose = "state-file" }` | Tags applied to the bucket. |
| `sse_algorithm` | string | `"AES256"` | `AES256` (SSE-S3) or `aws:kms` (SSE-KMS, requires external KMS on the cluster). |
| `kms_master_key_id` | string | `null` | KMS key ID. Required when `sse_algorithm = "aws:kms"`. |
| `abort_incomplete_multipart_upload_days` | number | `7` | Days after which incomplete MPUs are aborted. |
| `noncurrent_version_expiration_days` | number | `90` | Days after which superseded state versions are permanently deleted. |

## Outputs

| Name | Description | Sensitive |
|---|---|---|
| `bucket_name` | State bucket name. | No |
| `account_name` | Dedicated state account name. | No |
| `account_id` | Scality account ID. | No |
| `access_key` | Stable access key — use as `AWS_ACCESS_KEY_ID` in downstream backend config. | Yes |
| `secret_key` | Stable secret key — use as `AWS_SECRET_ACCESS_KEY` in downstream backend config. | Yes |

## Caveats

- **Empty the bucket before `terraform destroy`.** Scality accounts can
  only be deleted when they own no resources — buckets, users, or
  policies. Terraform tears down users and policies in the right order
  if they're managed in the same configuration, but bucket *contents*
  (S3 objects, all noncurrent versions, and delete markers) live outside
  Terraform's lifecycle. Clear them manually first, otherwise the bucket
  fails to delete and the account can't be torn down.
- **Protect your state file.** It contains the dedicated account's secret
  key in plain text. Treat the state of *this* module especially
  carefully — losing it locks you out of the account.
