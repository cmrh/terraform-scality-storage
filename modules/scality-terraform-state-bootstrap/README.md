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

## Two modes — `console_login`

| `console_login` | Account resource | UI access | Bootstrap key ownership | Layered stable key? |
|---|---|---|---|---|
| `true` (default) | `scality_console_account` | Yes — password output via `console_password` | UI-owned (rotatable from Console) | Yes — `scality_account_access_key` |
| `false` | `scality_account` | No | Terraform-owned | No (the bootstrap key is used directly) |

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
  source  = "cmrh/storage/scality//modules/scality-terraform-state-bootstrap"
  version = "~> 1.2"

  account_email = "platform@example.com"
  bucket_name   = "platform-tf-state"
}

output "state_bucket" {
  value = module.tf_state.bucket_name
}

output "state_access_key" {
  value     = module.tf_state.access_key
  sensitive = true
}

output "state_secret_key" {
  value     = module.tf_state.secret_key
  sensitive = true
}

output "state_console_password" {
  value     = module.tf_state.console_password
  sensitive = true
}
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
  source  = "cmrh/storage/scality//modules/scality-terraform-state-bootstrap"
  version = "~> 1.2"

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

Scality storage ignores conditional writes (`If-None-Match`), so the S3
backend's `use_lockfile` doesn't prevent concurrent writes. Whether you need
locking, and how to add it, is covered in
[State locking](../../docs/pointers/state-locking.md). Object versioning on
the bucket keeps prior state versions for recovery.

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
| `kms_master_key_id` | string | `null` | KMS key ID, used with `sse_algorithm = "aws:kms"`. | both |
| `abort_incomplete_multipart_upload_days` | number | `7` | Days after which incomplete MPUs are aborted. | both |
| `noncurrent_version_expiration_days` | number | `90` | Days after which superseded state versions expire. | both |
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

- **Changing `console_login` after apply breaks the module.** The apply
  fails with `access denied` on the state bucket, which still belongs to
  the old account, after the old account's Terraform-owned key has already
  been destroyed. Terraform can then no longer manage or destroy the
  bucket. Pick the mode before the first apply.
- **Empty the bucket before `terraform destroy`.** Bucket contents (objects,
  noncurrent versions, delete markers) aren't managed by Terraform, and a
  bucket that still holds any fails to delete, which also stops the
  account from being deleted.
- **Protect your state file.** It contains the dedicated account's
  credentials and (when `console_login = true`) the auto-generated
  Console password in plain text. Treat the state of *this* module
  especially carefully — losing it locks you out of the account.
