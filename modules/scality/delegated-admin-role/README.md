# scality / delegated-admin-role

Creates an IAM role inside a **sub-account** that one specific IAM user in a
**management account** can assume. The management account then manages the
sub-account's buckets and IAM resources through the provider's
`assume_role` block. It doesn't need the sub-account's long-lived keys, and
it doesn't need an operator user inside every sub-account.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_iam_policy`: the role's permissions (default `s3:* + iam:*`)
- `scality_iam_role`: the role, with a trust policy naming exactly one IAM
  user ARN
- `scality_iam_role_policy_attachment`: attaches the policy to the role

## How it fits

```
superadmin ──creates──▶ sub-account ──contains──▶ role "account-manager"   ◀── this module
                                                   trusts: mgmt user ARN
                                                   policy: s3:* + iam:*
                                                            ▲ sts:AssumeRole
management account ── IAM user "delegator" ────────────────┘
                       (application-identity + sts:AssumeRole policy)
```

Deployment takes **two stages, in separate root configs**. A role must exist
before a provider can be configured to assume it, so the role can't be
created and used in the same apply.

1. **Bootstrap.** The superadmin creates the accounts. The management user is
   created with the management account's keys. This module then runs with
   each sub-account's keys to create the role.
2. **Managed.** One provider alias per sub-account, each using the
   management user's keys plus `assume_role { role_arn = ... }`. Resources in
   this stage omit `account_access_key` / `account_secret_key`.

## Usage

### Stage 1: bootstrap

```hcl
module "mgmt_account" {
  source  = "cmrh/storage/scality//modules/scality/scality-account-management"
  version = "~> 1.0"

  account_name  = "mgmt"
  account_email = "mgmt@example.com"
}

module "sub_a_account" {
  source  = "cmrh/storage/scality//modules/scality/scality-account-management"
  version = "~> 1.0"

  account_name  = "customer-a"
  account_email = "customer-a@example.com"
}

# The management user. application-identity with a custom policy that
# allows sts:AssumeRole on the sub-accounts' roles only.
module "delegator" {
  source  = "cmrh/storage/scality//modules/scality/application-identity"
  version = "~> 1.0"

  account_access_key = module.mgmt_account.access_key
  account_secret_key = module.mgmt_account.secret_key

  username    = "delegator"
  policy_name = "assume-sub-account-roles"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = [module.sub_a_admin.role_arn]
    }]
  })
}

module "sub_a_admin" {
  source  = "cmrh/storage/scality//modules/scality/delegated-admin-role"
  version = "~> 1.0"

  account_access_key = module.sub_a_account.access_key
  account_secret_key = module.sub_a_account.secret_key

  # Build the ARN as a string rather than referencing module.delegator.user_arn.
  # See "Caveats" for why.
  trusted_user_arn = "arn:aws:iam::${module.mgmt_account.account_id}:user/delegator"
}
```

### Stage 2: managed (separate root config)

```hcl
# The management user's keys (stage 1 outputs), e.g. via TF_VAR_* env vars.
variable "delegator_access_key" {
  type      = string
  sensitive = true
}

variable "delegator_secret_key" {
  type      = string
  sensitive = true
}

# One aliased provider per sub-account.
provider "scality" {
  alias      = "customer_a"
  access_key = var.delegator_access_key
  secret_key = var.delegator_secret_key

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/account-manager" # stage 1: module.sub_a_admin.role_arn
  }
}

# No account_access_key / account_secret_key: the assumed role is used.
resource "scality_bucket" "data" {
  provider = scality.customer_a
  bucket   = "customer-a-data"
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | The sub-account's key, typically its account-root key. Used only at bootstrap. |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `trusted_user_arn` | string | (required) | The one management-account user allowed to assume the role (`arn:aws:iam::<id>:user/<name>`). Account-root principals are rejected by design. |
| `role_name` | string | `"account-manager"` | Role name. Forces replacement. |
| `policy_name` | string | `null` | Managed policy name. Defaults to `<role_name>-perms`. |
| `policy_document` | string | `null` | Custom JSON permissions. Defaults to `s3:* + iam:*` on `*`. Updates apply in-place. |

## Outputs

| Name | Description | Sensitive |
|---|---|---|
| `role_name` | Role name. | No |
| `role_arn` | Role ARN, for the managed stage's `assume_role { role_arn }`. Available once the policy is attached. | No |
| `policy_arn` | ARN of the attached permissions policy. | No |
| `effective_policy` | Rendered JSON permissions (default or custom). | No |

## Caveats

- **Trust is pinned to one IAM user by design.** Trusting an account root
  would let any sufficiently privileged user in the management account
  assume the role. `trusted_user_arn` only accepts a user ARN.
- **Trust matches the ARN string, not a unique user ID.** Deleting the
  management user and recreating it *with the same name* gets the role
  access back. After a compromise:
  - Rotate the management user's access key, or delete the user.
  - Create the replacement user under a **new name**, and update
    `trusted_user_arn` in every sub-account.
  - Role sessions last **1 hour**. Plan for sessions issued before the
    response to stay usable until they expire.
- **Changing the trust policy replaces the role.** Every
  `scality_iam_role` attribute forces replacement, so changing
  `trusted_user_arn` recreates the role. The module replaces the attachment
  along with the role (`replace_triggered_by`), so the old role can be
  deleted cleanly.
- **Prefer a string for `trusted_user_arn`.** Referencing
  `module.<user>.user_arn` directly makes the value unknown whenever that
  user is replaced, so every sub-account's role is replaced too, even when
  the name is unchanged. Build the ARN from the management account ID and
  the username instead, as in the example.
- **If the role is deleted outside Terraform, plans fail.** The attachment's
  refresh errors with `NoSuchEntity`, and every plan fails until you remove
  it from state:

  ```bash
  terraform state rm 'module.<name>.scality_iam_role_policy_attachment.this'
  ```

  The next apply recreates the role and the attachment.
- **The default policy lets the role edit its own permissions.** `iam:*`
  includes the role and its policy. To restrict that, pass a
  `policy_document` with your own statements.
- **One provider alias per sub-account.** Terraform doesn't support
  `for_each` on provider blocks, so the managed stage declares each
  sub-account's provider explicitly (or generates them, e.g. with
  Terragrunt).
- **Protect your state file.** The bootstrap stage's state holds each
  sub-account's root keys and the management user's secret key in plain
  text.
