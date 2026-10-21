# Operator pattern — lifecycle example

Demonstrates and regression-tests the operator pattern end-to-end on a
single cluster:

```
cluster-admin  ->  account
account-root   ->  operator user
operator       ->  bucket
operator       ->  app user (read-write on bucket)
```

Cluster-admin and account-root credentials are used only for the
account and operator bootstrap. Everything past that is operator-driven.

Both `apply` and `destroy` must succeed end-to-end. This example is
referenced by the `integration` workflow to catch any regression in the
`application-identity` output dependency graph (the operator's policy
must outlive every resource that uses the operator's keys).

## Configure

Provider credentials via environment:

```sh
export SCALITY_ENDPOINT=https://s3.example.com
export SCALITY_ACCESS_KEY=...
export SCALITY_SECRET_KEY=...
```

The account name defaults to `operator-test-01`. Override for CI or
repeat runs:

```sh
export TF_VAR_account_name=my-test-account
```

## Run

```sh
tofu init
tofu apply
tofu destroy
```

## What's tested

- Operator user can create a bucket using its own keys.
- Operator user can create an IAM user + access key + inline policy.
- On destroy, all resources tear down in the correct order — the
  operator's own policy survives until the resources that depend on
  its `iam:*` permission are gone.
