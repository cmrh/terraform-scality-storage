# ARTESCA edge to RING example

An ARTESCA bucket replicated to a RING bucket.

- **RING:** an account, an operator user, and a versioned target bucket with
  a replication user (`ring-replication-target`).
- **ARTESCA:** an account, an app user with a key, a versioned bucket, a RING
  location using the replication user's key, and a replication rule
  (`edge-replication`).

Objects written to the ARTESCA bucket appear under the same keys at the root
of the RING bucket.

## Run

```sh
# RING (superadmin, creates the RING account)
export SCALITY_ENDPOINT=https://s3.ring.example.com
export SCALITY_ACCESS_KEY=...
export SCALITY_SECRET_KEY=...

# ARTESCA
export ARTESCA_MANAGEMENT_ENDPOINT=https://...
export ARTESCA_OIDC_URL=https://...
export ARTESCA_USERNAME=...
export ARTESCA_PASSWORD=...
export ARTESCA_S3_ENDPOINT=https://...

export TF_VAR_ring_endpoint=https://s3.ring.example.com   # as reached from ARTESCA

terraform init
terraform apply
```

## Destroy

Both buckets hold objects. ARTESCA's are removed by `force_destroy`; the
RING bucket is versioned and must be emptied by hand. Read the RING keys and
bucket name first: a failed destroy clears the outputs from state.

```sh
export AWS_ACCESS_KEY_ID="$(terraform output -raw ring_operator_access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform output -raw ring_operator_secret_key)"
RING_BUCKET="$(terraform output -raw ring_bucket)"

TF_VAR_force_destroy=true terraform apply
TF_VAR_force_destroy=true terraform destroy   # removes ARTESCA, then fails on the RING bucket

# delete every object version and delete marker in the RING bucket
while :; do
  page=$(aws --endpoint-url "$SCALITY_ENDPOINT" s3api list-object-versions \
    --bucket "$RING_BUCKET" --max-items 1000 --output json \
    | jq -c '{Objects: ([(.Versions // [])[], (.DeleteMarkers // [])[]] | map({Key, VersionId})), Quiet: true}')
  [ "$(jq '.Objects | length' <<<"$page")" = 0 ] && break
  aws --endpoint-url "$SCALITY_ENDPOINT" s3api delete-objects --bucket "$RING_BUCKET" --delete "$page"
done

TF_VAR_force_destroy=true terraform destroy
```
