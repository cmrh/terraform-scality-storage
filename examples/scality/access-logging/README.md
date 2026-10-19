# Access logging example

Creates an account, an operator user, an application bucket and a log
bucket. The application bucket's access logs are delivered to the log bucket
under `<app bucket>/` and deleted after 90 days.

Server access logging must be enabled on the cluster.

## Run

```sh
export SCALITY_ENDPOINT=http://your-cluster:8080
export SCALITY_ACCESS_KEY=...   # superadmin
export SCALITY_SECRET_KEY=...

terraform init
terraform apply
```

## Destroy

A bucket must be empty before it can be deleted. Read the operator's keys
first: a failed destroy clears the outputs from state.

```sh
export AWS_ACCESS_KEY_ID="$(terraform output -raw operator_access_key)"
export AWS_SECRET_ACCESS_KEY="$(terraform output -raw operator_secret_key)"
LOGS="$(terraform output -raw log_bucket)"; APP="$(terraform output -raw app_bucket)"

terraform destroy   # disables logging, then fails on the non-empty buckets
aws --endpoint-url "$SCALITY_ENDPOINT" s3 rm --recursive "s3://$LOGS/"
terraform destroy
```

If the application bucket holds objects, empty it the same way (it's
versioned, so delete every object version, not just the objects).
