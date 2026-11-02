# scality / group-access

Creates a Scality IAM group with managed policies attached and, optionally,
its members. Grants access per group rather than per user: users get the
group's permissions in addition to their own.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `scality_group` — the group
- `scality_iam_policy` — one managed policy per entry in `policies`
- `scality_iam_group_policy_attachment` — attaches each policy in `policies`
  and `policy_arns` to the group
- `scality_group_membership` — the group's members, only when `members` is set

## Usage

### Read-only access to a bucket for a set of users

```hcl
module "archive_readers" {
  source  = "cmrh/storage/scality//modules/scality-group-access"
  version = "~> 1.4"

  account_access_key = module.acme_operator.access_key
  account_secret_key = module.acme_operator.secret_key

  group_name = "archive-readers"

  policies = {
    archive-read = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:GetObjectVersion"]
          Resource = "arn:aws:s3:::acme-archive/*"
        },
        {
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
          Resource = "arn:aws:s3:::acme-archive"
        },
      ]
    })
  }

  members = [module.ingest.username, module.reporting.username]
}
```

[`examples/group-access`](../../examples/group-access) wires this to
`scality-application-identity` users.

### Attaching policies managed elsewhere

```hcl
  policy_arns = {
    shared-list = scality_iam_policy.shared_list.arn
  }
```

The keys are labels of your choice. `policy_arns` is a map rather than a list
so an ARN created in the same apply works.

### Members

`members` is authoritative: users not listed are removed from the group, and
`[]` empties it. Leave it `null` (the default) to manage membership
elsewhere. Changing it from a list to `null` removes the users that were
listed.

## Adopting an existing group

Import the group, each policy, each attachment and, when `members` is set,
the membership. With `SCALITY_ACCOUNT_ACCESS_KEY` /
`SCALITY_ACCOUNT_SECRET_KEY` set, the IDs carry no credentials:

```hcl
module "read_only" {
  source = "cmrh/storage/scality//modules/scality-group-access"
  # ...
  group_name = "ReadOnlyGroup"
  policies   = { ReadOnlyPolicy = file("${path.module}/ReadOnlyPolicy.json") }
  members    = ["alice"]
}

import {
  to = module.read_only.scality_group.this
  id = "ReadOnlyGroup"
}

import {
  to = module.read_only.scality_iam_policy.this["ReadOnlyPolicy"]
  id = "arn:aws:iam::123456789012:policy/ReadOnlyPolicy"
}

import {
  to = module.read_only.scality_iam_group_policy_attachment.created["ReadOnlyPolicy"]
  id = "ReadOnlyGroup:arn:aws:iam::123456789012:policy/ReadOnlyPolicy"
}

import {
  to = module.read_only.scality_group_membership.this[0]
  id = "ReadOnlyGroup"
}
```

An attachment of a policy passed in `policy_arns` imports to
`scality_iam_group_policy_attachment.existing["<key>"]`. Fetch a policy's
document with `aws iam get-policy-version`; formatting differences don't
show as changes. See [adoption](../../docs/adoption.md) for adopting the
account and its buckets and users.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_access_key` | string (sensitive) | (required) | Caller credentials (operator recommended). |
| `account_secret_key` | string (sensitive) | (required) | Paired with `account_access_key`. |
| `group_name` | string | (required) | IAM group name. Forces replacement. |
| `policies` | map(string) | `{}` | Policy name => JSON document, created and attached. Renaming a policy replaces it. |
| `policy_arns` | map(string) | `{}` | Label => ARN of an existing policy to attach. |
| `members` | set(string) | `null` | Usernames in the group. Authoritative; `null` leaves membership unmanaged. |

## Outputs

| Name | Description |
|---|---|
| `group_name` | Group name. |
| `group_id` | Unique group identifier. |
| `group_arn` | Group ARN. |
| `policy_arns` | ARNs of every policy attached to the group. |

## Caveats

- **Destroy fails while the group has members this module doesn't manage.**
  IAM won't delete a group with members (`DeleteConflict`), and it won't
  delete those users while they're in it. Remove them from the group, or
  list them in `members`, before destroying.
- **Policies are detached before they're deleted.** Policies in `policies`
  are attached by reference, so destroy detaches them before deleting the
  policy or the group.
