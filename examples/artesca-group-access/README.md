# artesca-group-access example

Creates an account, two application users (`ingest` and `reporting`) with
read-write access to their own buckets, and an archive bucket. The
`archive-readers` group gives both users read-only access to the archive
bucket.

## Run

```sh
export ARTESCA_MANAGEMENT_ENDPOINT=https://...
export ARTESCA_OIDC_URL=https://...
export ARTESCA_USERNAME=...
export ARTESCA_PASSWORD=...
export ARTESCA_S3_ENDPOINT=https://...

terraform init
terraform apply
```

Each application's keys:

```sh
terraform output -json app_access_keys
terraform output -json app_secret_keys
```

## Destroy

```sh
terraform destroy
```

The buckets must be empty. A user added to `archive-readers` outside
Terraform blocks the destroy; remove it from the group first.
