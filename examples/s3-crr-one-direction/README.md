# Example: one-direction CRR

End-to-end runnable example wiring source → destination cross-region
replication between two Scality clusters. Stands up everything the
feature needs in a single `tofu apply`:

- An account on each cluster (`scality-account-management`)
- A full-access operator user on each account (`account-operator`)
- A versioned bucket on each cluster (`application-bucket`)
- IAM roles, policies, and the replication configuration (`s3-crr`)
- A writer user on source and a reader user on dest, for verification
  (`application-identity`)

For active-active replication, see [`s3-crr-bidirectional`](../s3-crr-bidirectional/).

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

## Verify

```bash
SRC_AK=$(tofu output -raw source_writer_access_key)
SRC_SK=$(tofu output -raw source_writer_secret_key)
DST_AK=$(tofu output -raw dest_reader_access_key)
DST_SK=$(tofu output -raw dest_reader_secret_key)
SRC_BUCKET=$(tofu output -raw source_bucket_name)
DST_BUCKET=$(tofu output -raw dest_bucket_name)

# Upload to source
echo "hello $(date)" > /tmp/test.txt
AWS_ACCESS_KEY_ID=$SRC_AK AWS_SECRET_ACCESS_KEY=$SRC_SK \
  aws --endpoint-url "$SCALITY_ENDPOINT" \
  s3 cp /tmp/test.txt "s3://$SRC_BUCKET/"

# List on dest — CRR is asynchronous; allow a few seconds
AWS_ACCESS_KEY_ID=$DST_AK AWS_SECRET_ACCESS_KEY=$DST_SK \
  aws --endpoint-url "$TF_VAR_dest_endpoint" \
  s3 ls "s3://$DST_BUCKET/"
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

Removes the buckets, accounts, users, and replication configuration
in dependency order. No orphans.
