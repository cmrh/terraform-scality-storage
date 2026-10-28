# scality / account-operator

Creates an **operator user** inside a Scality account — a user with
`s3:* + iam:*` permissions intended to manage all other users and
buckets within the account on Terraform's behalf.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## Why operator?

Account-root credentials (the keys output by `scality-account-management`
or `scality-terraform-state-bootstrap`) are the foundational identity of an
account. Using them for routine Terraform operations:

- Couples credential rotation to the account itself — account-root keys
  can't be rotated independently.
- Makes audit logs indistinguishable: every API call looks like
  "account root."
- Bypasses least-privilege within the account.

The operator pattern creates a dedicated user with broad permissions
inside the account. Downstream wrapper modules (`application-identity`,
`application-bucket`, `compliance-bucket`, etc.) take the operator's
keys as input. Account-root keys are used **only** to bootstrap the
operator, then reserved for break-glass scenarios.

## Composition

This module is a thin wrapper over `application-identity`:

- `application-identity` provides the user + access key + policy primitive
- `account-operator` baked-in policy is `s3:* + iam:*` on `Resource: "*"`,
  loaded from `policy.json` inside the module

If you want to replicate this manually, use `application-identity` with
your own `policy_document`.

## Usage

```hcl
# 1. Create the tenant account (account-root credentials are emitted here)
module "tenant_acme" {
  source        = "cmrh/storage/scality//modules/scality-account-management"
  version       = "~> 1.2"
  account_name  = "acme"
  account_email = "platform@acme.example.com"
}

# 2. Bootstrap the operator using account-root credentials — only place
#    those credentials are consumed
module "acme_operator" {
  source  = "cmrh/storage/scality//modules/scality-account-operator"
  version = "~> 1.2"

  account_access_key = module.tenant_acme.access_key
  account_secret_key = module.tenant_acme.secret_key
}

# 3. Everything downstream uses operator credentials
module "acme_app" {
  source  = "cmrh/storage/scality//modules/scality-application-identity"
  version = "~> 1.2"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  username    = "acme-app"
  bucket_arns = ["arn:aws:s3:::acme-data"]
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Account-root access key. |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `operator_username` | string | `"operator"` | Operator user's username. |
| `policy_name` | string | `null` | Policy name. Defaults to `<operator_username>-policy`. |

## Outputs

| Name | Description | Sensitive |
|---|---|---|
| `username` | Operator username. | No |
| `user_arn` | Operator user ARN. | No |
| `access_key` | Operator's access key. **Use this as `account_access_key` for downstream modules.** | Yes |
| `secret_key` | Operator's secret key. | Yes |

## Caveats

- **Account-root credentials become break-glass.** Once this module has
  applied, switch every downstream module to operator credentials. Reach
  for account-root only when the operator user itself is compromised or
  needs to be recreated.
- **Same operational caveats as `application-identity`** apply — secret
  key is one-time, most fields force replacement, etc. See its README.
- **Protect your state file.** Contains the operator's secret key in
  plain text.
