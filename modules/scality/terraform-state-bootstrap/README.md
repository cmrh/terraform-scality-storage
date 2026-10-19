# scality / terraform-state-bootstrap

Provisions a dedicated Scality account and S3 bucket suitable for storing
Terraform/OpenTofu state files.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu — commands, syntax,
> and state files are identical.

## What it creates

By default (`console_login = true`):
- `scality_console_account` (with a randomly generated Console password)
- `scality_account_access_key` layered for stable Terraform ownership
- A versioned `scality_bucket` (versioning is mandatory)
- `scality_bucket_encryption` (SSE-S3 by default)
- `scality_bucket_lifecycle` (abort incomplete MPUs, expire noncurrent versions)

When `console_login = false`:
- `scality_account` (no UI; supports `account_attributes`)
- The same bucket + encryption + lifecycle as above

The default mirrors `scality-account-management` for consistency. Set
`console_login = false` if you want a strictly headless state account
without UI access.

## Two modes — `console_login`

| `console_login` | Account resource | UI access | Bootstrap key ownership | Layered stable key? |
|---|---|---|---|---|
| `true` (default) | `scality_console_account` | Yes — password output via `console_password` | UI-owned (rotatable from Console) | Yes — `scality_account_access_key` |
| `false` | `scality_account` | No | Terraform-owned | No (the bootstrap key is used directly) |

**Toggling the flag after apply is destructive** — the account is
recreated, new credentials are issued, and the bucket is detached
(it's owned by the old account). Plan accordingly.

## Usage

This module bootstraps the state backend, so it must run with **local
state** the first time. Pin the provider, configure the admin endpoint
via environment variables, and apply:

```bash
export SCALITY_ENDPOINT="https://your-scality-endpoint"
export SCALITY_ACCESS_KEY="admin-access-key"
export SCALITY_SECRET_KEY="admin-secret-key"
```

```hcl
terraform {
  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
  }
}

provider "scality" {}

module "tf_state" {
  source  = "cmrh/storage/scality//modules/scality/terraform-state-bootstrap"
  version = "~> 1.0"

  account_email = "platform@example.com"
  bucket_name   = "platform-tf-state"
}

output "state_bucket"           { value = module.tf_state.bucket_name }
output "state_access_key"       { value = module.tf_state.access_key, sensitive = true }
output "state_secret_key"       { value = module.tf_state.secret_key, sensitive = true }
output "state_console_password" { value = module.tf_state.console_password, sensitive = true }
```

```bash
terraform init
terraform apply
```

Capture the outputs with `terraform output -raw <name>` for the downstream
backend configuration below. The `state_console_password` is for admins
who want UI access to the state account — change it via the Console UI
after first login.

### Headless variant

```hcl
module "tf_state" {
  source  = "cmrh/storage/scality//modules/scality/terraform-state-bootstrap"
  version = "~> 1.0"

  account_email = "platform@example.com"
  bucket_name   = "platform-tf-state"
  console_login = false
}
```

`console_password` is `null` in this mode.

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
  }
}
```

Pass the credentials via environment variables (recommended) so they
never land in version control:

```bash
export AWS_ACCESS_KEY_ID="$(terraform output -raw state_access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform output -raw state_secret_key)"

terraform init
```

## State Locking

For state locking, configure your downstream projects with a
Terraform/OpenTofu backend that has built-in locking:

| Backend | Locking |
|---|---|
| [`pg`](https://opentofu.org/docs/language/settings/backends/pg/) | Postgres advisory lock |
| [`http`](https://opentofu.org/docs/language/settings/backends/http/) with a lock-aware server | Server-side locks |
| Terraform Cloud / Scalr / Spacelift / etc. | Built into the platform |

These backends manage state on their own infrastructure rather than in
S3. The state bucket created by this module is suitable for storing
state in single-operator workflows or as a snapshot store alongside
one of these backends. Object versioning on the bucket preserves prior
state file content for recovery in either case.

## Inputs

| Name | Type | Default | Description | Effective when |
|---|---|---|---|---|
| `account_name` | string | `"terraform-state"` | Dedicated account name. | both |
| `account_email` | string | (required) | Account email. | both |
| `console_login` | bool | `true` | `true` → `scality_console_account` (UI access, generated password); `false` → `scality_account` (headless). | both |
| `account_attributes` | map(string) | `{ managed_by = "terraform", purpose = "state-file" }` | Custom attributes for the account. | only `console_login = false` |
| `bucket_name` | string | (required) | State bucket name (3-63 chars). | both |
| `tags` | map(string) | `{ managed_by = "terraform", purpose = "state-file" }` | Tags on the state bucket. | both |
| `sse_algorithm` | string | `"AES256"` | `AES256` or `aws:kms`. | both |
| `kms_master_key_id` | string | `null` | KMS key ID. Required when `sse_algorithm = "aws:kms"`. | both |
| `abort_incomplete_multipart_upload_days` | number | `7` | Days after which incomplete MPUs are aborted. | both |
| `noncurrent_version_expiration_days` | number | `90` | Days after which superseded state versions expire. | both |

> When `console_login = true`, `account_attributes` is silently ignored —
> `scality_console_account` does not accept custom attributes.

## Outputs

| Name | Description | Sensitive | Available when |
|---|---|---|---|
| `bucket_name` | State bucket name. | No | both |
| `account_name` | Dedicated state account name. | No | both |
| `account_id` | Scality account identifier. | No | both |
| `access_key` | Stable access key for backend config. | Yes | both |
| `secret_key` | Stable secret key for backend config. | Yes | both |
| `console_password` | Auto-generated Console password. | Yes | only `console_login = true` (null otherwise) |

## Caveats

- **Switching `console_login` is destructive.** The account is recreated;
  the existing bucket detaches and downstream backends become unreachable
  via the old credentials. Don't toggle this on a live state bucket
  without a migration plan.
- **`console_password` is one-time.** After the admin changes it in the
  Console UI, the value in Terraform state is stale (the resource Read
  does not query the API for the password). Treat it as a bootstrap
  value, not a long-term reference.
- **Empty the bucket before `terraform destroy`.** Scality accounts can
  only be deleted when they own no resources — buckets, users, or
  policies. Terraform tears down users and policies in the right order
  if they're managed in the same configuration, but bucket *contents*
  (S3 objects, all noncurrent versions, and delete markers) live outside
  Terraform's lifecycle. Clear them manually first, otherwise the bucket
  fails to delete and the account can't be torn down.
- **Protect your state file.** It contains the dedicated account's
  credentials and (when `console_login = true`) the auto-generated
  Console password in plain text. Treat the state of *this* module
  especially carefully — losing it locks you out of the account.
