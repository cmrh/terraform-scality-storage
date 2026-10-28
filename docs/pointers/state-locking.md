# State locking

*Last checked: 2026-10-27*

## What locking prevents

Locking stops two runs from changing the same state at once. Without it,
two overlapping applies can both read the old state, and the last one to
write wins. The resources one run created are then missing from state.

## Do you need it?

Often not. Locking matters when runs can overlap:

- **One person, or a small team that coordinates:** agree who applies and
  when. That's enough.
- **CI pipelines:** run applies for the same state one at a time, for
  example with a concurrency group per state key.
- **Larger teams, or several pipelines sharing state:** a lock is worth
  adding.

Splitting state into smaller pieces (per environment or per component) also
makes overlapping runs less likely.

## Scality storage and the S3 lockfile

Scality storage ignores the `If-None-Match` header, which the S3 backend's
native lockfile (`use_lockfile = true`) depends on. The lockfile looks like
it works but doesn't prevent overlapping runs, so don't rely on it.

## Adding a lock table

If you need a lock, point the backend at a DynamoDB-compatible service such
as [dynoxide](https://github.com/nubo-db/dynoxide):

```hcl
terraform {
  backend "s3" {
    bucket         = "tfstate"
    key            = "prod/terraform.tfstate"
    dynamodb_table = "tflock"

    endpoints = {
      s3       = "https://s3.example.com"
      dynamodb = "https://dynoxide.example.com"
    }
    # ...plus the region and path-style settings your endpoint needs
  }
}
```

The table needs a partition key named `LockID`, of type String. Terragrunt's
`remote_state` block passes the same backend arguments.

OpenTofu supports DynamoDB locking with no plans to deprecate it
([docs](https://opentofu.org/docs/language/settings/backends/s3/)). Terraform
marks it deprecated, to be removed in a future minor version
([docs](https://developer.hashicorp.com/terraform/language/backend/s3)).
dynoxide describes itself as built for development, testing and CI.
