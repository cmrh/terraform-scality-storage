# Example: bidirectional (active-active) CRR

End-to-end runnable example wiring **active-active** cross-region
replication between two Scality clusters. Same composition as
[`../one-direction/`](../one-direction/) but with `bidirectional = true`
on the `s3-crr` module call — the IAM roles and policies are
symmetric, so a single flag flips one-way replication into two-way.

What gets created on each cluster:

- An account (`scality-account-management`)
- A full-access operator user (`account-operator`)
- A versioned bucket (`application-bucket`)
- IAM role + policy + attachment, with backbeat-trusted role
  (`s3-crr`)
- Replication configuration in both directions (`s3-crr`,
  `bidirectional = true`)
- A read-write writer user for verification (`application-identity`)

## Prerequisites

- Two reachable Scality clusters
- Cluster-admin credentials for each (one set per cluster)
- `tofu` (or `terraform`) installed
- `aws` CLI for verification

## Credentials

The source cluster is configured by the provider's standard
environment variables; the destination is configured by Terraform
input variables.

```bash
# Source cluster — read natively by the scality provider
export SCALITY_ENDPOINT=https://s3.source.example.com
export SCALITY_ACCESS_KEY=...
export SCALITY_SECRET_KEY=...

# Destination cluster — Terraform-level inputs
export TF_VAR_dest_endpoint=https://s3.dest.example.com
export TF_VAR_dest_access_key=...
export TF_VAR_dest_secret_key=...
```

## Apply

```bash
tofu init
tofu plan
tofu apply
```

## Verify — both directions

```bash
SRC_AK=$(tofu output -raw source_writer_access_key)
SRC_SK=$(tofu output -raw source_writer_secret_key)
DST_AK=$(tofu output -raw dest_writer_access_key)
DST_SK=$(tofu output -raw dest_writer_secret_key)

# Source → Destination
echo "from-source $(date)" > /tmp/fs.txt
AWS_ACCESS_KEY_ID=$SRC_AK AWS_SECRET_ACCESS_KEY=$SRC_SK \
  aws --endpoint-url "$SCALITY_ENDPOINT" \
  s3 cp /tmp/fs.txt s3://crr-bidir-source-data/

AWS_ACCESS_KEY_ID=$DST_AK AWS_SECRET_ACCESS_KEY=$DST_SK \
  aws --endpoint-url "$TF_VAR_dest_endpoint" \
  s3 ls s3://crr-bidir-dest-data/

# Destination → Source
echo "from-dest $(date)" > /tmp/fd.txt
AWS_ACCESS_KEY_ID=$DST_AK AWS_SECRET_ACCESS_KEY=$DST_SK \
  aws --endpoint-url "$TF_VAR_dest_endpoint" \
  s3 cp /tmp/fd.txt s3://crr-bidir-dest-data/

AWS_ACCESS_KEY_ID=$SRC_AK AWS_SECRET_ACCESS_KEY=$SRC_SK \
  aws --endpoint-url "$SCALITY_ENDPOINT" \
  s3 ls s3://crr-bidir-source-data/
```

Add `--no-verify-ssl` to the `aws` commands if your clusters use
self-signed TLS certificates.

## Day-to-day administration

The operator credentials (full S3 + IAM on each account) are also
output, so you can use them directly with the AWS CLI for ongoing
admin tasks:

```bash
tofu output -raw source_operator_access_key
tofu output -raw source_operator_secret_key
```

## Teardown

```bash
tofu destroy
```

Removes everything in dependency order. No orphans.
