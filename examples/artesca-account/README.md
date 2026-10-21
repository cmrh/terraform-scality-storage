# ARTESCA account example

Creates an ARTESCA account and outputs its S3 keys.

## Run

```sh
export ARTESCA_MANAGEMENT_ENDPOINT=https://...
export ARTESCA_OIDC_URL=https://...
export ARTESCA_USERNAME=...
export ARTESCA_PASSWORD=...

terraform init
terraform apply
terraform output -raw access_key
```

## Destroy

```sh
terraform destroy
```
