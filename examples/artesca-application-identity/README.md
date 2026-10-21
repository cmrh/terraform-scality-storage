# ARTESCA application identity example

Creates an account, a bucket, and an `app` user with read-write access to
that bucket only.

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

## Destroy

```sh
terraform destroy
```

The bucket must be empty.
