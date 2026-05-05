# scality / s3-crr

Configures cross-region replication (CRR) between two Scality buckets
on **two independent clusters**. The buckets must already exist (with
versioning enabled — typically created via `application-bucket` on
each cluster). This module wires up the IAM roles, policies, and
replication configuration that S3 needs to ship objects from one
cluster to the other.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

On the **source** cluster:
- IAM managed policy granting replication permissions on both buckets
- IAM role with a `backbeat` service trust policy
- Role-policy attachment
- A `crr-operator` user, inline policy, and access key — internal to
  CRR mechanics. Credentials are not surfaced.

On the **destination** cluster:
- The same set: IAM policy, role, attachment, internal `crr-operator` user

Replication wiring:
- `scality_bucket_replication` on the source bucket pointing at the
  destination bucket (always)
- A second `scality_bucket_replication` on the destination bucket
  pointing back at the source bucket (only when `bidirectional = true`)

The IAM policy on each side is **symmetric** — it grants read and write
on both buckets — so the same configuration supports either one-direction
or bidirectional setups. Toggling `bidirectional` only adds or removes
the reverse `scality_bucket_replication`.

## Two-provider configuration

This module needs two `scality` provider configurations — one per
cluster — passed in via `providers` at the module call site:

```hcl
terraform {
  required_providers {
    scality = {
      source  = "scality/scality"
      version = "~> 0.4"
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
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/s3-crr?ref=v0.1.0"

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
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/scality-account-management?ref=v0.1.0"
  providers = { scality = scality.src }

  account_name  = "crr-source"
  account_email = "platform@example.com"
}

module "source_operator" {
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/account-operator?ref=v0.1.0"
  providers = { scality = scality.src }

  account_access_key = module.source_account.access_key
  account_secret_key = module.source_account.secret_key
}

module "source_bucket" {
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/application-bucket?ref=v0.1.0"
  providers = { scality = scality.src }

  account_access_key = module.source_operator.access_key
  account_secret_key = module.source_operator.secret_key
  bucket_name        = "crr-source-data"
}

# --- Destination cluster ---

module "dest_account" {
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/scality-account-management?ref=v0.1.0"
  providers = { scality = scality.dst }

  account_name  = "crr-dest"
  account_email = "platform@example.com"
}

module "dest_operator" {
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/account-operator?ref=v0.1.0"
  providers = { scality = scality.dst }

  account_access_key = module.dest_account.access_key
  account_secret_key = module.dest_account.secret_key
}

module "dest_bucket" {
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/application-bucket?ref=v0.1.0"
  providers = { scality = scality.dst }

  account_access_key = module.dest_operator.access_key
  account_secret_key = module.dest_operator.secret_key
  bucket_name        = "crr-dest-data"
}

# --- CRR ---

module "crr" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/s3-crr?ref=v0.1.0"

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
  source = "...//modules/scality/s3-crr?ref=v0.1.0"
  providers = { scality.source = scality.src, scality.dest = scality.dst }

  # ...all other inputs as above...

  bidirectional = true
}
```

## Granting application access and verifying replication

The internal `crr-operator` user this module creates supports CRR's
replication mechanics. Its credentials are not surfaced — application
access and manual verification go through dedicated users created via
the `application-identity` module.

Example: a writer on the source side and a reader on the destination
side, useful both for application traffic and for confirming
replication after `terraform apply`:

```hcl
# Source-side writer — for the application or for uploading test objects
module "source_writer" {
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/application-identity?ref=v0.1.0"
  providers = { scality = scality.src }

  account_access_key = module.source_operator.access_key
  account_secret_key = module.source_operator.secret_key

  username       = "crr-source-writer"
  bucket_arns    = [module.source_bucket.bucket_arn]
  access_pattern = "read-write"
}

# Destination-side reader — for confirming that replicated objects landed
module "dest_reader" {
  source    = "git::https://github.com/scality/scality-s3-tf-modules.git//modules/scality/application-identity?ref=v0.1.0"
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
| `source_crr_operator_username` | Source-cluster CRR operator username (for reference). | No |
| `dest_crr_operator_username` | Destination-cluster CRR operator username (for reference). | No |

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
  The `crr-operator` user is internal to CRR and its credentials are
  not surfaced.
- **Protect your state file.** It contains the CRR operator's secret
  key (held internally) along with caller credentials.
