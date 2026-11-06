# Adopting existing ARTESCA accounts, buckets and users

Bring ARTESCA buckets, users and groups created by hand under the artesca
modules without recreating them. `scripts/artesca-adopt.sh` reads an account
and writes module calls plus `import {}` blocks; you review, plan, and apply.
For Scality S3, see [adoption](adoption.md).

## What it covers

| Found in the account | Becomes |
|---|---|
| Bucket with object lock | `artesca-compliance-bucket` |
| Bucket with a transition rule | `artesca-tiered-bucket` |
| Any other bucket | `artesca-application-bucket` |
| User | `artesca-application-identity`, with its inline policies and attached managed policies |
| Group | `artesca-group-access`, with its members and managed policies |

Each bucket keeps its encryption, tags and bucket policy. Its lifecycle rules
are adopted one by one into the module rules they match: cleanup (noncurrent
expiry, multipart abort and delete markers, for the whole bucket), current
expiry, and current and noncurrent transitions. Other rules stay on the
bucket as they are, outside Terraform.

A group's module call owns the account policies attached only to that group,
keeping their names and documents. Other policies, such as one attached to
several groups or to a user, are attached by ARN and left unmanaged.

Not covered, listed on stderr and left as they are: replication, roles,
locations, inline group policies, and object lock or tiered buckets stored in
a location other than ARTESCA's own. A group with inline policies can't be
destroyed until they're deleted.

## Before you start

- awscli, jq and curl.
- Terraform or OpenTofu 1.5 or later (for `import {}` blocks).
- The artesca provider's sign-in settings, for a login that can manage the
  account.

## 1. Generate

In a new, empty directory:

```bash
export ARTESCA_MANAGEMENT_ENDPOINT="https://management.artesca.example.com"
export ARTESCA_OIDC_URL="https://iam.artesca.example.com"
export ARTESCA_USERNAME="..."
export ARTESCA_PASSWORD="..."
export ARTESCA_S3_ENDPOINT="https://s3.artesca.example.com"

/path/to/terraform-scality-storage/scripts/artesca-adopt.sh --account acme
```

The script signs in as the provider does and only reads from the cluster. It
writes `adopt.tf` and prints notes on stderr. `adopt.tf` holds no
credentials: the module calls take the account name.

Options: `--out FILE`, `--iam-endpoint URL` and `--sts-endpoint URL` (when
they can't be derived from the management and S3 endpoints),
`--module-source` and `--module-version` (to point at a `git::` or local copy
of the modules), and `--account-module NAME` (see
[Adopting the account](#adopting-the-account)).

## 2. Review

Read every `# REVIEW:` line in `adopt.tf` and every stderr note:

- **Object lock without a default retention:** the module requires one.
- **A tiered bucket without versioning:** the module turns it on.
- **Lifecycle rules left as they are:** they keep running, outside
  Terraform.

If a change isn't acceptable, keep that bucket or user out: delete its module
call and import blocks.

## 3. Plan

Add the provider to the directory:

```hcl
terraform {
  required_providers {
    artesca = {
      source  = "cmrh/artesca"
      version = "~> 1.2"
    }
  }
}

provider "artesca" {}
```

```bash
terraform init
terraform plan
```

Expect:

- **to import:** every bucket with its encryption, tags, policy and adopted
  lifecycle rules, every user with its policies and attachments, and every
  group with its policies, attachments and memberships.
- **to add:** a new access key per user.
- **to change:** `force_destroy` on buckets and users, which import can't
  read back.
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

Move each application to its new key, then delete the old one in the ARTESCA
UI or with `aws iam delete-access-key`.

## Adopting the account

Import the account into `artesca-account-management`. Its email can't be
read back, so set it as registered; ARTESCA stores it lowercased.

```hcl
module "acme" {
  source  = "cmrh/storage/scality//modules/artesca-account-management"
  version = "~> 2.0"

  account_name  = "acme"
  account_email = "platform@acme.example.com"   # as registered
}

import {
  to = module.acme.artesca_account.this
  id = "acme"
}
```

Generate with `--account-module acme`: each call then takes
`module.acme.account_name`, so destroy deletes the buckets, users and groups
before the account.

Expect a one-off in-place `email` change on the account. The account's own
keys aren't recovered by import.

**Destroy deletes the account only once nothing else is left in it.** A
managed policy attached by ARN (one attached to several users or groups) is
left in the account after destroy; delete it, then destroy again.
