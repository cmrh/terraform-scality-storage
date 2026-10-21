# ARTESCA tiered bucket example

An ARTESCA bucket whose objects move to a RING bucket after
`transition_days` (30 by default).

- **RING:** an account, an operator, and a versioned bucket with a key that
  can write, read and delete objects (`scality-ring-replication-target`,
  `purpose = "tiering"`).
- **ARTESCA:** a RING location, an account, the tiered bucket, and an `app`
  user with read-write access.

Objects stay readable through ARTESCA after they move.

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

Both buckets may hold objects. ARTESCA's are removed by `force_destroy`; the
RING bucket is versioned and must be emptied by hand. Read the RING keys and
bucket name first: a failed destroy clears the outputs from state.

```sh
export AWS_ACCESS_KEY_ID="$(terraform output -raw ring_operator_access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform output -raw ring_operator_secret_key)"
RING_BUCKET="$(terraform output -raw ring_bucket)"

TF_VAR_force_destroy=true terraform apply
TF_VAR_force_destroy=true terraform destroy   # removes ARTESCA, then fails on a non-empty RING bucket

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
