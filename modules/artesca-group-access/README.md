# artesca-group-access

Creates an ARTESCA IAM group with managed policies attached and, optionally,
its members. Grants access per group rather than per user: users get the
group's permissions in addition to their own.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `artesca_group`: the group
- `artesca_policy`: one managed policy per entry in `policies`
- `artesca_group_policy_attachment`: attaches each policy in `policies` and
  `policy_arns` to the group
- `artesca_group_membership`: one per user in `members`

## Prerequisites

- cmrh/artesca provider 1.1 or later.

## Usage

### Read-only access to a bucket for a set of users

```hcl
module "archive_readers" {
  source  = "cmrh/storage/scality//modules/artesca-group-access"
  version = "~> 2.0"

  account_name = module.account.account_name
  group_name   = "archive-readers"

  policies = {
    archive-read = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:GetObjectVersion"]
          Resource = "${module.archive.bucket_arn}/*"
        },
        {
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
          Resource = module.archive.bucket_arn
        },
      ]
    })
  }

  members = [module.ingest.username, module.reporting.username]
}
```

[`examples/artesca-group-access`](../../examples/artesca-group-access) wires
this to `artesca-application-identity` users.

### Attaching policies managed elsewhere

```hcl
  policy_arns = {
    shared-list = artesca_policy.shared_list.arn
  }
```

The keys are labels of your choice. `policy_arns` is a map rather than a list
so an ARN created in the same apply works. Reference the policy rather than
writing its ARN, so destroy detaches it before deleting the policy.

### Members

Each user in `members` gets its own membership. Removing a user from the list
removes it from the group. Users added to the group outside this module are
left in it.

## Adopting an existing group

Import the group, each policy, each attachment and each membership. The IDs
start with the account name:

```hcl
module "readers" {
  source = "cmrh/storage/scality//modules/artesca-group-access"
  # ...
  account_name = "acme"
  group_name   = "readers"
  policies     = { read-only = file("${path.module}/read-only.json") }
  members      = ["alice"]
}

import {
  to = module.readers.artesca_group.this
  id = "acme/readers"
}

import {
  to = module.readers.artesca_policy.this["read-only"]
  id = "acme/arn:aws:iam::123456789012:policy/read-only"
}

import {
  to = module.readers.artesca_group_policy_attachment.created["read-only"]
  id = "acme/readers/arn:aws:iam::123456789012:policy/read-only"
}

import {
  to = module.readers.artesca_group_membership.this["alice"]
  id = "acme/readers/alice"
}
```

An attachment of a policy passed in `policy_arns` imports to
`artesca_group_policy_attachment.existing["<key>"]`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `account_name` | string | (required) | Account that owns the group. Forces replacement. |
| `group_name` | string | (required) | IAM group name. Forces replacement. |
| `policies` | map(string) | `{}` | Policy name => JSON document, created and attached. Document changes apply in place; renaming a policy replaces it. |
| `policy_arns` | map(string) | `{}` | Label => ARN of an existing policy to attach. |
| `members` | set(string) | `[]` | Usernames to add to the group. |

## Outputs

| Name | Description |
|---|---|
| `group_name` | Group name. |
| `group_id` | Unique group identifier. |
| `group_arn` | Group ARN. |
| `policy_arns` | ARNs of every policy attached to the group. |

## Caveats

- **Destroy fails while the group has members this module doesn't manage.**
  ARTESCA won't delete a group that still has members. Remove them from the
  group, or list them in `members`, before destroying.
- **Policies are detached before they're deleted.** Policies in `policies`
  are attached by reference, so destroy detaches them before deleting the
  policy or the group.
