# scality / scality-account-management

Provisions a Scality account with a stable S3 access key suitable for use
by downstream wrapper modules in this repository (or any direct provider
resources that need per-account credentials).

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## Two modes — `console_login`

This module wraps two underlying Scality account resources, selected by
the `console_login` flag:

| `console_login` | Resource | Best for | UI access | Notes |
|---|---|---|---|---|
| `true` (default) | `scality_console_account` | Tenant accounts where customers/admins need to log into the Console | Yes — random password generated, exposed via `console_password` output | Bootstrap S3 key is **UI-owned** (the Console can rotate it). The module always layers an additional `scality_account_access_key` that Terraform owns exclusively, and that's the credential exposed by the `access_key`/`secret_key` outputs. |
| `false` | `scality_account` | Headless / automation accounts | No | Bootstrap S3 key is already Terraform-owned, no layered key needed. Supports `account_attributes` and `external_account_id`. |
## What it creates

When `console_login = true`:
- `scality_console_account` (with `generate_random_password = true`)
- `scality_account_access_key` layered for stable Terraform ownership

When `console_login = false`:
- `scality_account` (with optional `custom_attributes` and
  `external_account_id`)

## Usage

### Tenant onboarding — Console UI access (default)

```hcl
module "tenant_acme" {
  source  = "cmrh/storage/scality//modules/scality-account-management"
  version = "~> 1.2"

  account_name  = "acme"
  account_email = "platform@acme.example.com"
  account_quota = 53687091200    # 50 GB
}

output "acme_console_password" {
  value     = module.tenant_acme.console_password
  sensitive = true
}
```

```bash
terraform apply
terraform output -raw acme_console_password    # share with the tenant — they should change it via UI
```

### Headless / automation account

```hcl
module "ci_account" {
  source  = "cmrh/storage/scality//modules/scality-account-management"
  version = "~> 1.2"

  account_name  = "ci-pipeline"
  account_email = "platform-ops@example.com"
  console_login = false

  account_attributes = {
    purpose = "ci-pipeline"
    owner   = "platform-team"
  }

  external_account_id = "platform-ci-001"
}
```

### Composing with downstream resources

The `access_key` / `secret_key` outputs feed any account-scoped Scality
resource (or wrapper module that takes per-account credentials):

```hcl
module "tenant_acme" {
  source        = "cmrh/storage/scality//modules/scality-account-management"
  version       = "~> 1.2"
  account_name  = "acme"
  account_email = "platform@acme.example.com"
}

resource "scality_bucket" "acme_data" {
  account_access_key = module.tenant_acme.access_key
  account_secret_key = module.tenant_acme.secret_key
  bucket             = "acme-data"
  versioning         = true
}
```

## Inputs

| Name | Type | Default | Description | Effective when |
|---|---|---|---|---|
| `account_name` | string | (required) | Account name (1-128 chars, alphanumeric + hyphens). Forces replacement. | both |
| `account_email` | string | (required) | Account email. Forces replacement. | both |
| `console_login` | bool | `true` | `true` → `scality_console_account`; `false` → `scality_account`. | both |
| `account_quota` | number | `null` | Max bytes; `null` leaves it unset; `0` sets no limit. Forces replacement. | both |
| `external_account_id` | string | `null` | External integration ID. Forces replacement. | only `console_login = false` |
| `account_attributes` | map(string) | `{}` | Custom key-value metadata. Max 10 entries. | only `console_login = false` |
## Outputs

| Name | Description | Sensitive | Available when |
|---|---|---|---|
| `account_name` | Created account name. | No | both |
| `account_id` | Account identifier. | No | both |
| `created_at` | Creation timestamp (ISO 8601). | No | both |
| `access_key` | Stable S3 access key (layered when `console_login = true`). | Yes | both |
| `secret_key` | Stable S3 secret key. | Yes | both |
| `console_password` | Auto-generated UI password. Customer should change it in Console after first login. | Yes | only `console_login = true` (null otherwise) |
| `account_arn` | Account ARN. | No | only `console_login = false` (null otherwise) |
| `canonical_id` | Canonical ID, used in bucket policies. | No | only `console_login = false` (null otherwise) |

## Caveats

- **Changing `console_login` after apply replaces the account.** The old
  account is destroyed and a new one is created, with a new ID and new
  keys. Creating the new account can take a second apply. Anything
  using the old keys must be reconfigured.
- **Account deletion fails while the account still owns resources**
  created outside this configuration (buckets, users, groups, policies,
  roles), with `DeleteConflict`. Bucket contents aren't managed by
  Terraform; empty buckets before `terraform destroy`.
- **Protect your state file.** It contains the account credentials in
  plain text.
