# ARTESCA storage location example

Creates a RING account, an operator, and a versioned RING bucket with a key
limited to what ARTESCA needs, then an ARTESCA location backed by that bucket.

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

export TF_VAR_ring_endpoint=https://s3.ring.example.com   # as reached from ARTESCA
# optional: export TF_VAR_endpoint_hostname=archive.s3.example.com

terraform init
terraform apply
```

## Destroy

```sh
terraform destroy
```
