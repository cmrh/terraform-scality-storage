# Example: bidirectional (active-active) CRR

Creates active-active cross-region replication between two Scality clusters.
Same composition as [`s3-crr-one-direction`](../s3-crr-one-direction/) but
with `bidirectional = true` on the `scality-s3-crr` module call, a read-write
verification user on the destination instead of a read-only one, and a
`crr-bidir-` name prefix.

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

## Verify — both directions

```bash
SRC_AK=$(tofu output -raw source_writer_access_key)
SRC_SK=$(tofu output -raw source_writer_secret_key)
DST_AK=$(tofu output -raw dest_writer_access_key)
DST_SK=$(tofu output -raw dest_writer_secret_key)
SRC_BUCKET=$(tofu output -raw source_bucket_name)
DST_BUCKET=$(tofu output -raw dest_bucket_name)

# Source → Destination
echo "from-source $(date)" > /tmp/fs.txt
AWS_ACCESS_KEY_ID=$SRC_AK AWS_SECRET_ACCESS_KEY=$SRC_SK \
  aws --endpoint-url "$SCALITY_ENDPOINT" \
  s3 cp /tmp/fs.txt "s3://$SRC_BUCKET/"

AWS_ACCESS_KEY_ID=$DST_AK AWS_SECRET_ACCESS_KEY=$DST_SK \
  aws --endpoint-url "$TF_VAR_dest_endpoint" \
  s3 ls "s3://$DST_BUCKET/"

# Destination → Source
echo "from-dest $(date)" > /tmp/fd.txt
AWS_ACCESS_KEY_ID=$DST_AK AWS_SECRET_ACCESS_KEY=$DST_SK \
  aws --endpoint-url "$TF_VAR_dest_endpoint" \
  s3 cp /tmp/fd.txt "s3://$DST_BUCKET/"

AWS_ACCESS_KEY_ID=$SRC_AK AWS_SECRET_ACCESS_KEY=$SRC_SK \
  aws --endpoint-url "$SCALITY_ENDPOINT" \
  s3 ls "s3://$SRC_BUCKET/"
```

Add `--no-verify-ssl` to the `aws` commands if your clusters use
self-signed TLS certificates.

## Destroy

A bucket must be empty before it can be deleted. If you uploaded test
objects, delete every object version in both buckets first.

```bash
tofu destroy
```
