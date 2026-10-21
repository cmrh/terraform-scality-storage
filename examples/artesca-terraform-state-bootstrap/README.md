# ARTESCA Terraform state bootstrap example

Creates a dedicated account, a versioned and encrypted state bucket, and a
state user. Point a project's `s3` backend at the bucket with the state user's
keys; see the module README for the backend settings.

## Run

```sh
export ARTESCA_MANAGEMENT_ENDPOINT=https://...
export ARTESCA_OIDC_URL=https://...
export ARTESCA_USERNAME=...
export ARTESCA_PASSWORD=...
export ARTESCA_S3_ENDPOINT=https://...

terraform init
terraform apply
terraform output -raw access_key
```

## Destroy

Delete the state objects (every version) from the bucket, then:

```sh
terraform destroy
```
