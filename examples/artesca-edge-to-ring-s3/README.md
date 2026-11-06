# artesca-edge-to-ring-s3 example

An ARTESCA bucket replicated to a Scality S3 bucket, through a RING S3 location
(`mode = "ring-s3"`, the default) or CRR over STS (`mode = "crr"`).

- **Scality S3:** an account, an operator user, and a versioned target bucket with
  a replication user (`scality-ring-s3-target`). In `crr` mode the
  user can only assume a destination role, which writes the replicas.
- **ARTESCA:** an account, an app user with a key, a versioned bucket, a
  location (RING S3 or CRR) using the replication user's key, and a
  replication rule (`artesca-edge-replication`).

Objects written to the ARTESCA bucket appear under the same keys at the root
of the Scality S3 bucket.

## Run

```sh
# Scality S3 (superadmin, creates the account)
export SCALITY_ENDPOINT=https://s3.ring.example.com
export SCALITY_ACCESS_KEY=...
export SCALITY_SECRET_KEY=...

# ARTESCA
export ARTESCA_MANAGEMENT_ENDPOINT=https://...
export ARTESCA_OIDC_URL=https://...
export ARTESCA_USERNAME=...
export ARTESCA_PASSWORD=...
export ARTESCA_S3_ENDPOINT=https://...

export TF_VAR_ring_s3_endpoint=https://s3.ring.example.com   # as reached from ARTESCA

terraform init
terraform apply
```

For CRR over STS (a destination role on Scality S3 instead of a write key), also
set:

```sh
export TF_VAR_mode=crr
export TF_VAR_ring_s3_sts_endpoint=https://sts.ring.example.com   # as reached from ARTESCA
```

## Destroy

Both buckets hold objects. ARTESCA's are removed by `force_destroy`; the
Scality S3 bucket is versioned and must be emptied by hand. Read the Scality S3 keys and
bucket name first: a failed destroy clears the outputs from state.

```sh
export AWS_ACCESS_KEY_ID="$(terraform output -raw ring_s3_operator_access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform output -raw ring_s3_operator_secret_key)"
RING_BUCKET="$(terraform output -raw ring_s3_bucket)"

TF_VAR_force_destroy=true terraform apply
TF_VAR_force_destroy=true terraform destroy   # removes ARTESCA, then fails on the Scality S3 bucket

# delete every object version and delete marker in the Scality S3 bucket
while :; do
  page=$(aws --endpoint-url "$SCALITY_ENDPOINT" s3api list-object-versions \
    --bucket "$RING_BUCKET" --max-items 1000 --output json \
    | jq -c '{Objects: ([(.Versions // [])[], (.DeleteMarkers // [])[]] | map({Key, VersionId})), Quiet: true}')
  [ "$(jq '.Objects | length' <<<"$page")" = 0 ] && break
  aws --endpoint-url "$SCALITY_ENDPOINT" s3api delete-objects --bucket "$RING_BUCKET" --delete "$page"
done

TF_VAR_force_destroy=true terraform destroy
```
