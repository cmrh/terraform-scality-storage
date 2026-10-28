# Adopting existing accounts, buckets and users

Bring accounts, buckets and users created by hand under the modules without recreating
them. `scripts/scality-adopt.sh` reads an account and writes module calls plus
`import {}` blocks; you review, plan, and apply.

## What it covers

| Found in the account | Becomes |
|---|---|
| Bucket with object lock | `scality-compliance-bucket` |
| Any other bucket | `scality-application-bucket` |
| User with exactly one inline policy | `scality-application-identity`, keeping the policy name and document |

Not covered, listed on stderr and left as they are: bucket policies, bucket
logging, replication, roles, groups, users with no or several inline policies,
and managed policy attachments. The script doesn't adopt the account itself;
to bring the account under `scality-account-management` too, see
[Adopting the account](#adopting-the-account).

## Before you start

- awscli and jq.
- Terraform or OpenTofu 1.5 or later (for `import {}` blocks).
- Credentials of the account that owns the buckets and users.
- The cluster's endpoint.

## 1. Generate

In a new, empty directory:

```bash
export SCALITY_ENDPOINT="https://your-scality-endpoint"
export SCALITY_ACCOUNT_ACCESS_KEY="account-access-key"
export SCALITY_ACCOUNT_SECRET_KEY="account-secret-key"

/path/to/terraform-scality-storage/scripts/scality-adopt.sh
terraform fmt
```

The script only reads from the cluster. It writes `adopt.tf` and prints notes
on stderr. `adopt.tf` holds no credentials: the module calls take
`var.account_access_key` and `var.account_secret_key`.

Options: `--out FILE`, `--iam-endpoint URL` (when IAM isn't on the S3
endpoint), `--module-source` and `--module-version` (to point at a `git::` or
local copy instead of the registry). Set `SCALITY_INSECURE_SKIP_VERIFY=true`
for a self-signed endpoint.

## 2. Review

Read every `# REVIEW:` line in `adopt.tf` and every stderr note. Each marks a
setting the module can't express as it is today, so apply will change it:

- **No default encryption:** the module adds SSE-S3.
- **Lifecycle rules the module can't express** (prefix or tag filters,
  transitions, disabled rules): the module's rules replace them. The module's
  rules cover abort-incomplete-MPU, noncurrent expiry and current expiry for
  the whole bucket. The generated values mirror what the bucket has today.
- **Object lock without a default retention:** the module requires one.

If a change isn't acceptable, keep that bucket or user out: delete its module
call and import blocks.

## 3. Plan

Add the provider to the directory:

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
```

```bash
export SCALITY_ACCESS_KEY="admin-access-key"   # provider credentials
export SCALITY_SECRET_KEY="admin-secret-key"
export TF_VAR_account_access_key="$SCALITY_ACCOUNT_ACCESS_KEY"
export TF_VAR_account_secret_key="$SCALITY_ACCOUNT_SECRET_KEY"

terraform init
terraform plan
```

Expect:

- **to import:** every bucket, user and inline policy.
- **to add:** a new access key per user, plus encryption where a `# REVIEW`
  line said so.
- **to change:** `versioning` and `tags` set to the values the bucket already
  has (the provider doesn't record them on import), a one-off policy
  whitespace update, and the lifecycle changes from your review.
- **to destroy: 0.** If anything says `must be replaced`, stop and don't apply.

## 4. Apply

```bash
terraform apply
terraform plan   # expect: No changes
```

## 5. Rotate the access keys

Existing access keys aren't imported, because their secrets can't be read
back. Apply created a new key for each user:

```bash
terraform output -raw user_<name>_access_key
terraform output -raw user_<name>_secret_key
```

Move each application to its new key, then delete the old one:

```bash
export AWS_ACCESS_KEY_ID="$SCALITY_ACCOUNT_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SCALITY_ACCOUNT_SECRET_KEY"
aws --endpoint-url "$SCALITY_ENDPOINT" iam list-access-keys --user-name <user>
aws --endpoint-url "$SCALITY_ENDPOINT" iam delete-access-key --user-name <user> --access-key-id <old-key-id>
```

A user can hold 4 access keys; the script flags users already at the limit.

## Afterwards

The `import {}` blocks have done their job and can be deleted. The state now
holds the account credentials and the new user keys; see
[secrets](pointers/secrets.md) for keeping them safe.

## Adopting the account

An existing account, created through the Console or through IAM, can be
imported into `scality-account-management` or
`scality-terraform-state-bootstrap`. Import can't read back the account's
keys, so pass one of its existing keys in `account_credentials`; the module
creates a Terraform-owned key from it and outputs that key to the modules
chained after it.

```hcl
variable "account_credentials" {
  type = object({
    access_key = string
    secret_key = string
  })
  sensitive = true
}

module "acme" {
  source  = "cmrh/storage/scality//modules/scality-account-management"
  version = "~> 1.3"

  account_name        = "acme"
  account_email       = "platform@acme.example.com"   # as registered
  console_login       = false
  account_credentials = var.account_credentials
}

import {
  to = module.acme.scality_account.this[0]
  id = "acme"
}
```

```bash
export TF_VAR_account_credentials='{"access_key":"...","secret_key":"..."}'
terraform plan    # expect: the account imported, a new key added, 0 to destroy
```

For `scality-terraform-state-bootstrap`, the import address is
`module.<name>.scality_account.state[0]`.

- **Use `console_login = false`, even for an account created through the
  Console.** Console login keeps working. Importing as `console_login = true`
  would replace the account, because its settings can't be read back.
- **Leave `external_account_id` unset.** Import doesn't record it, so setting it
  forces a replacement. The account keeps its external ID.
- **Keep the key you pass in valid, and keep `account_credentials` set.** The
  module manages its own key with it; changing it replaces that key.
- **Destroy deletes the account only once its IAM content is gone** (groups,
  policies, users). An adopted account may already hold some, such as
  `FullAccessGroup` / `FullAccessPolicy` and `ReadOnlyGroup` /
  `ReadOnlyPolicy`. Before destroying, detach the policies from the groups,
  then delete the groups, then the policies.

Expect a one-off in-place `custom_attributes` change on the account.
