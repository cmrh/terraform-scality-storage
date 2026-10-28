# Example: one-direction CRR

Creates one-direction cross-region replication between two Scality clusters:

- An account on each cluster (`scality-account-management`)
- A full-access operator user on each account (`scality-account-operator`)
- A versioned bucket on each cluster (`scality-application-bucket`)
- IAM roles, policies, and the replication configuration (`scality-s3-crr`)
- A writer user on source and a reader user on dest, for verification
  (`scality-application-identity`)

The operator keys are outputs too (`source_operator_access_key` and so on).
For active-active replication, see [`s3-crr-bidirectional`](../s3-crr-bidirectional/).

## Run

The source cluster is configured by the provider's environment variables, the
destination by input variables. Both need cluster-admin credentials.

```bash
export SCALITY_ENDPOINT=https://s3.source.example.com
export SCALITY_ACCESS_KEY=...
export SCALITY_SECRET_KEY=...

export TF_VAR_dest_endpoint=https://s3.dest.example.com
export TF_VAR_dest_access_key=...
export TF_VAR_dest_secret_key=...

tofu init
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

# List on dest — CRR is asynchronous; allow 30 seconds or more
AWS_ACCESS_KEY_ID=$DST_AK AWS_SECRET_ACCESS_KEY=$DST_SK \
  aws --endpoint-url "$TF_VAR_dest_endpoint" \
  s3 ls "s3://$DST_BUCKET/"
```

Add `--no-verify-ssl` to the `aws` commands if your clusters use
self-signed TLS certificates.

## Destroy

A bucket must be empty before it can be deleted. If you uploaded test
objects, delete every object version in both buckets first.

```bash
tofu destroy
```
