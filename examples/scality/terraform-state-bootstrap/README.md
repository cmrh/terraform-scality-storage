# Terraform state bootstrap example

Creates a dedicated account, with Console login, and a versioned, encrypted
bucket to hold Terraform or OpenTofu state.

## Run

```sh
export SCALITY_ENDPOINT=http://your-cluster:8080
export SCALITY_ACCESS_KEY=...   # superadmin
export SCALITY_SECRET_KEY=...
export SCALITY_CONSOLE_ENDPOINT=https://your-console
export SCALITY_CONSOLE_USERNAME=...
export SCALITY_CONSOLE_PASSWORD=...

terraform init
terraform apply
```

## Destroy

```sh
terraform destroy
```

The bucket must have no object versions left.
