# ARTESCA application bucket example

Creates an account, a versioned and encrypted bucket with a tag and a
30-day expiration rule, and an `app` user with read-write access to it.

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
TF_VAR_force_destroy=true terraform apply
TF_VAR_force_destroy=true terraform destroy
```
