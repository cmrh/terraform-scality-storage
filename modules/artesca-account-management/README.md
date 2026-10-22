# artesca-account-management

An ARTESCA account and its S3 keys.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `artesca_account`: the account, with an access key and secret key
  generated at creation

## Prerequisites

- cmrh/artesca provider 1.1 or later.

## Usage

```hcl
module "account" {
  source  = "cmrh/storage/scality//modules/artesca-account-management"
  version = "~> 1.2"

  account_name  = "team-a"
  account_email = "team-a@example.com"
}
```

Account-scoped `artesca_*` resources and modules take the account by name
(`module.account.account_name`); the provider authenticates them through its
own login, so they don't need the account's keys. Use `access_key` and
`secret_key` for S3 clients.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | (required) | Account name: 1-128 letters, numbers and hyphens. Forces replacement. |
| `account_email` | string | (required) | Account email. Forces replacement. |

## Outputs

| Name | Description |
|---|---|
| `account_name` | Account name. |
| `account_id` | Account ID. |
| `account_arn` | Account root ARN. |
| `canonical_id` | Canonical ID. |
| `access_key` | S3 access key (sensitive). |
| `secret_key` | S3 secret key (sensitive). |

## Caveats

- **The keys are set at creation and kept in state.** After an import
  they're empty.
- **Destroy fails while the account still holds a bucket created outside
  Terraform** (`Account not empty`).
