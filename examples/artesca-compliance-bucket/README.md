# ARTESCA compliance bucket example

Creates an account, a bucket with object lock and a 1-day `GOVERNANCE`
default retention, and an `app` user with read-write access to it. Objects
the app writes are locked for a day.

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
