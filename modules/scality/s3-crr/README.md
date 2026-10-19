# scality / s3-crr

Wires up the cross-region replication (CRR) feature on Scality: IAM
roles and policies on each cluster, plus the `scality_bucket_replication`
configuration that backbeat acts on. Supports one-direction
(source → dest) and bidirectional (active-active) topologies via a
single variable.

CRR end-to-end is a **composed feature** — see "Where this module
fits" below. This module's contract is narrow on purpose: give it
pre-existing bucket names and operator credentials on each cluster,
and it makes replication work between them. It does not create
accounts, buckets, or application users — those are owned by their
respective modules.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## Where this module fits

CRR is delivered end-to-end by composing several modules. Each owns
one piece of the feature:

| Module | Owns | Per cluster |
|---|---|---|
| `scality-account-management` | An account | One on each |
| `account-operator` | Operator user + credentials on the account (used to call this module) | One on each |
| `application-bucket` | The source / destination bucket, with versioning on | One on each |
| **`s3-crr`** (this module) | IAM roles, policies, attachments, and the replication configuration(s) | Both sides, in one call |
| `application-identity` (optional) | Application users with scoped bucket access — e.g., a writer on source and a reader on dest for replication verification | As needed |

The "Full composition" example under [Usage](#usage) chains these in
order. If you already have accounts, operator credentials, and
buckets on each cluster, you can skip straight to calling `s3-crr`
with those existing inputs.

## What this module creates

On the **source** cluster:
- IAM managed policy granting replication permissions on the **source
  bucket**
- IAM role with a `backbeat` service trust policy
- Role-policy attachment

On the **destination** cluster:
- The same set: IAM policy (scoped to the **destination bucket**),
  role, attachment

Replication wiring:
- `scality_bucket_replication` on the source bucket pointing at the
  destination bucket (always)
- A second `scality_bucket_replication` on the destination bucket
  pointing back at the source bucket (only when `bidirectional = true`)

Each side's IAM policy is identical in shape and action set but
**scoped to its local bucket only** — backbeat on each cluster only
holds permissions on its own bucket. The role-pair wired into
`scality_bucket_replication.role` (`source_role_arn,dest_role_arn`)
handles cross-cluster routing. The same configuration supports
one-direction or bidirectional setups; toggling `bidirectional` only
adds or removes the reverse `scality_bucket_replication`.

**No user is created for CRR.** Replication is performed by the
**backbeat service** on each cluster, which assumes the IAM role
above (its trust policy grants `sts:AssumeRole` to
`Principal.Service = "backbeat"`). The role's permissions are what
backbeat uses to read locally and write to the counterpart bucket —
no user-side credential is involved in CRR itself. For application
traffic or for verifying replication after apply, use
`application-identity`.

## Two-provider configuration

This module needs two `scality` provider configurations — one per
cluster — passed in via `providers` at the module call site:

```hcl
terraform {
  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
  }
}

provider "scality" {
  alias = "src"
  # source-cluster credentials (e.g., from SCALITY_* env vars)
}

provider "scality" {
  alias      = "dst"
  endpoint   = var.dest_endpoint
  access_key = var.dest_access_key
  secret_key = var.dest_secret_key
}

module "crr" {
  source  = "cmrh/storage/scality//modules/scality/s3-crr"
  version = "~> 1.0"

  providers = {
    scality.source = scality.src
    scality.dest   = scality.dst
  }

  ...
}
```

## Recommended caller pattern

Use **operator credentials** for both `source_account_access_key` /
`source_account_secret_key` and the dest equivalents (the output of
`account-operator` on each cluster). Reserve account-root credentials
for break-glass.

## Usage

### Full composition: account → operator → bucket → CRR (one-direction)

```hcl
# --- Source cluster ---

module "source_account" {
  source    = "cmrh/storage/scality//modules/scality/scality-account-management"
  version   = "~> 1.0"
  providers = { scality = scality.src }

  account_name  = "crr-source"
  account_email = "platform@example.com"
}

module "source_operator" {
  source    = "cmrh/storage/scality//modules/scality/account-operator"
  version   = "~> 1.0"
  providers = { scality = scality.src }

  account_access_key = module.source_account.access_key
  account_secret_key = module.source_account.secret_key
}

module "source_bucket" {
  source    = "cmrh/storage/scality//modules/scality/application-bucket"
  version   = "~> 1.0"
  providers = { scality = scality.src }

  account_access_key = module.source_operator.access_key
  account_secret_key = module.source_operator.secret_key
  bucket_name        = "crr-source-data"
}

# --- Destination cluster ---

module "dest_account" {
  source    = "cmrh/storage/scality//modules/scality/scality-account-management"
  version   = "~> 1.0"
  providers = { scality = scality.dst }

  account_name  = "crr-dest"
  account_email = "platform@example.com"
}

module "dest_operator" {
  source    = "cmrh/storage/scality//modules/scality/account-operator"
  version   = "~> 1.0"
  providers = { scality = scality.dst }

  account_access_key = module.dest_account.access_key
  account_secret_key = module.dest_account.secret_key
}

module "dest_bucket" {
  source    = "cmrh/storage/scality//modules/scality/application-bucket"
  version   = "~> 1.0"
  providers = { scality = scality.dst }

  account_access_key = module.dest_operator.access_key
  account_secret_key = module.dest_operator.secret_key
  bucket_name        = "crr-dest-data"
}

# --- CRR ---

module "crr" {
  source  = "cmrh/storage/scality//modules/scality/s3-crr"
  version = "~> 1.0"

  providers = {
    scality.source = scality.src
    scality.dest   = scality.dst
  }

  source_account_access_key = module.source_operator.access_key
  source_account_secret_key = module.source_operator.secret_key
  source_bucket_name        = module.source_bucket.bucket_name

  dest_account_access_key = module.dest_operator.access_key
  dest_account_secret_key = module.dest_operator.secret_key
  dest_bucket_name        = module.dest_bucket.bucket_name
}
```

### Bidirectional (active-active) replication

Add a single line:

```hcl
module "crr" {
  source  = "cmrh/storage/scality//modules/scality/s3-crr"
  version = "~> 1.0"
  providers = { scality.source = scality.src, scality.dest = scality.dst }

  # ...all other inputs as above...

  bidirectional = true
}
```

## Granting application access and verifying replication

Application access and manual verification of replication go through
dedicated users created with the `application-identity` module — this
module does not create any users itself. Backbeat performs the
replication via the IAM role above; no user credential is part of the
CRR wiring.

Example: a writer on the source side and a reader on the destination
side, useful both for application traffic and for confirming
replication after `terraform apply`:

```hcl
# Source-side writer — for the application or for uploading test objects
module "source_writer" {
  source    = "cmrh/storage/scality//modules/scality/application-identity"
  version   = "~> 1.0"
  providers = { scality = scality.src }

  account_access_key = module.source_operator.access_key
  account_secret_key = module.source_operator.secret_key

  username       = "crr-source-writer"
  bucket_arns    = [module.source_bucket.bucket_arn]
  access_pattern = "read-write"
}

# Destination-side reader — for confirming that replicated objects landed
module "dest_reader" {
  source    = "cmrh/storage/scality//modules/scality/application-identity"
  version   = "~> 1.0"
  providers = { scality = scality.dst }

  account_access_key = module.dest_operator.access_key
  account_secret_key = module.dest_operator.secret_key

  username       = "crr-dest-reader"
  bucket_arns    = [module.crr.dest_bucket_arn]
  access_pattern = "read-only"
}
```

Then verify with awscli:

```bash
SRC_AK=$(terraform output -raw source_writer_access_key)
SRC_SK=$(terraform output -raw source_writer_secret_key)
DST_AK=$(terraform output -raw dest_reader_access_key)
DST_SK=$(terraform output -raw dest_reader_secret_key)

# Upload to source
AWS_ACCESS_KEY_ID=$SRC_AK AWS_SECRET_ACCESS_KEY=$SRC_SK \
  aws --endpoint-url "$SOURCE_ENDPOINT" s3 cp /etc/hostname "s3://crr-source-data/test"

# List on destination — replication is asynchronous; allow a few seconds
AWS_ACCESS_KEY_ID=$DST_AK AWS_SECRET_ACCESS_KEY=$DST_SK \
  aws --endpoint-url "$DEST_ENDPOINT" s3 ls "s3://crr-dest-data/"
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `source_account_access_key` | string (sensitive) | (required) | Source-cluster caller creds (operator recommended). |
| `source_account_secret_key` | string (sensitive) | (required) | Paired with `source_account_access_key`. |
| `source_bucket_name` | string | (required) | Existing source bucket (versioning required). |
| `dest_account_access_key` | string (sensitive) | (required) | Destination-cluster caller creds (operator recommended). |
| `dest_account_secret_key` | string (sensitive) | (required) | Paired with `dest_account_access_key`. |
| `dest_bucket_name` | string | (required) | Existing destination bucket (versioning required). |
| `bidirectional` | bool | `false` | When true, also replicates dest → source. |
| `role_name` | string | `"crr-role"` | IAM role name on each cluster. |
| `policy_name` | string | `"crr-policy"` | IAM managed policy name on each cluster. |

## Outputs

| Name | Description | Sensitive |
|---|---|---|
| `source_bucket_arn` | Source bucket ARN. | No |
| `dest_bucket_arn` | Destination bucket ARN. | No |
| `source_role_arn` | Source-cluster IAM role ARN (assumed by backbeat). | No |
| `dest_role_arn` | Destination-cluster IAM role ARN. | No |
| `bidirectional` | Whether reverse replication is configured. | No |

## Caveats

- **Both buckets must have versioning enabled.** `application-bucket`
  defaults to `versioning = true`; if you create the bucket some other
  way, ensure versioning is on before applying this module.
- **Lifecycle rules on replicated buckets need care.** The default
  `application-bucket` `noncurrent_version_expiration_days = 90` is
  usually fine — replication completes well within that window. If you
  set very short lifecycle expirations (hours/days), noncurrent versions
  may expire before replication ships them.
- **CRR is asynchronous.** There's no synchronous guarantee that an
  object written to the source is immediately visible on the
  destination. Allow seconds-to-minutes depending on cluster size and
  network.
- **Toggling `bidirectional` only adds or removes the reverse replication.**
  The IAM roles and policies are symmetric, so the rest of the wiring
  stays in place.
- **Use `application-identity` for application or verification access.**
  Backbeat handles replication via the IAM role this module creates;
  no user-side credential is part of the CRR mechanics. For app
  traffic or replication verification, layer `application-identity`
  on each side.
- **Protect your state file.** It contains the caller credentials
  passed in for each cluster.
