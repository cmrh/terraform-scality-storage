# Compliance bucket example

Creates an account, an operator user and a bucket with Object Lock. New
object versions are locked in GOVERNANCE mode for 1 day.

## Run

```sh
export SCALITY_ENDPOINT=http://your-cluster:8080
export SCALITY_ACCESS_KEY=...   # superadmin
export SCALITY_SECRET_KEY=...

terraform init
terraform apply
```

## Destroy

```sh
terraform destroy
```

The bucket must be empty.
