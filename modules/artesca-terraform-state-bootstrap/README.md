# artesca-terraform-state-bootstrap

A dedicated ARTESCA account with a versioned, encrypted bucket for Terraform
or OpenTofu state, and a user whose key can read and write that bucket only.

> Compatible with both Terraform and OpenTofu.

## What it creates

- an account (`artesca-account-management`)
- the state bucket (`artesca-application-bucket`): versioned, `AES256`
- a state user with a key and read-write access to the bucket only
  (`artesca-application-identity`)

## Prerequisites

- cmrh/artesca provider 1.2 or later.

## Usage

```hcl
module "state" {
  source  = "cmrh/storage/scality//modules/artesca-terraform-state-bootstrap"
  version = "~> 1.2"

  account_email = "platform@example.com"
  bucket_name   = "platform-tfstate"
}
```

Then, in each project that stores state there, with the state user's keys in
`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`:

```hcl
terraform {
  backend "s3" {
    bucket = "platform-tfstate"        # output: bucket_name
    key    = "PROJECT/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "https://s3.artesca.example.com"
    }

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    # insecure = true              # only if the endpoint's certificate isn't trusted
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | `"terraform-state"` | Account name. Forces replacement. |
| `account_email` | string | (required) | Account email. Forces replacement. |
| `bucket_name` | string | (required) | State bucket name. Forces replacement. |
| `username` | string | `"terraform-state"` | State user's name. |
| `tags` | map(string) | `{}` | Bucket tags. |

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | State bucket name. |
| `account_name` | Account name. |
| `account_id` | Account ID. |
| `access_key` | State user's access key (sensitive). |
| `secret_key` | State user's secret key (sensitive). |

## Caveats

- **No state locking through the S3 backend.** ARTESCA ignores conditional
  writes (`If-None-Match`), so `use_lockfile` doesn't prevent concurrent
  writes. See [State locking](../../docs/pointers/state-locking.md) for
  whether you need locking and how to add it.
- **Destroy needs an empty bucket.** The module has no `force_destroy` on
  purpose: delete the state objects (every version) first.
