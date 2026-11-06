# Terraform modules for Scality storage

Composite Terraform/OpenTofu modules for production deployments on Scality
storage. Built on the
[`scality`](https://github.com/cmrh/terraform-provider-scality) provider
(Scality S3) and the
[`artesca`](https://github.com/cmrh/terraform-provider-artesca)
provider (ARTESCA).

> Compatible with both Terraform and [OpenTofu](https://opentofu.org/). Examples use `terraform` or `tofu`; use whichever you run.

Browse everything on the [documentation site](https://cmrh.github.io/terraform-scality-storage/),
including pointers on [state locking](docs/pointers/state-locking.md) and
[secrets](docs/pointers/secrets.md).

## Module catalog

### Scality S3

| Module | Purpose |
|---|---|
| [`scality-terraform-state-bootstrap`](modules/scality-terraform-state-bootstrap) | Dedicated account + bucket for OpenTofu/Terraform state |
| [`scality-account-management`](modules/scality-account-management) | Tenant account (Console-UI or headless) + stable access key |
| [`scality-application-identity`](modules/scality-application-identity) | IAM user + access key + canned policy preset (read-only / read-write / bucket-admin) or custom JSON |
| [`scality-group-access`](modules/scality-group-access) | IAM group + managed policies + members |
| [`scality-account-operator`](modules/scality-account-operator) | Operator user (`iam:* + s3:*`) — recommended caller for downstream wrapper modules |
| [`scality-delegated-admin-role`](modules/scality-delegated-admin-role) | Sub-account role a single management-account user assumes (provider `assume_role`) to manage the sub-account's buckets and IAM |
| [`scality-application-bucket`](modules/scality-application-bucket) | Bucket + encryption + versioning + lifecycle hygiene |
| [`scality-access-log-bucket`](modules/scality-access-log-bucket) | Log bucket + delivery policy + retention, and access logging on source buckets |
| [`scality-compliance-bucket`](modules/scality-compliance-bucket) | Bucket + object lock (GOVERNANCE / COMPLIANCE) + retention period |
| [`scality-s3-crr`](modules/scality-s3-crr) | Cross-region replication (one-direction or bidirectional) between two clusters |
| [`scality-ring-s3-target`](modules/scality-ring-s3-target) | Versioned bucket + least-privilege key for an ARTESCA location backed by Scality S3 (replication, tiering or CRR over STS) |

### ARTESCA

| Module | Purpose |
|---|---|
| [`artesca-terraform-state-bootstrap`](modules/artesca-terraform-state-bootstrap) | Dedicated account + versioned state bucket + state user |
| [`artesca-account-management`](modules/artesca-account-management) | Account + S3 keys |
| [`artesca-application-identity`](modules/artesca-application-identity) | IAM user + access key + policy preset (read-only / read-write / bucket-admin) or custom JSON |
| [`artesca-group-access`](modules/artesca-group-access) | IAM group + managed policies + members |
| [`artesca-application-bucket`](modules/artesca-application-bucket) | Bucket + versioning + encryption + lifecycle cleanup + optional expiration and object lock |
| [`artesca-compliance-bucket`](modules/artesca-compliance-bucket) | Bucket + object lock + default retention (GOVERNANCE / COMPLIANCE) |
| [`artesca-tiered-bucket`](modules/artesca-tiered-bucket) | Bucket whose objects move to a Scality S3 (warm) or Versity tape (cold) location |
| [`artesca-storage-location`](modules/artesca-storage-location) | Scality S3 or Versity tape location + optional endpoint |
| [`artesca-edge-replication`](modules/artesca-edge-replication) | Account + users + bucket replicated to Scality S3, through a location or CRR over STS (pair with `scality-ring-s3-target`; see [`examples/artesca-edge-to-ring-s3`](examples/artesca-edge-to-ring-s3)) |

## Examples

Runnable configurations, one per directory under `examples/`.

### Scality S3

| Example | Shows |
|---|---|
| [`access-logging`](examples/access-logging) | Server access logs from a bucket delivered to a log bucket |
| [`delegated-admin-bootstrap`](examples/delegated-admin-bootstrap) / [`delegated-admin-managed`](examples/delegated-admin-managed) | A management account managing sub-accounts through an assumed role, in two stages |
| [`group-access`](examples/group-access) | Application users, plus a group with read-only access to a shared bucket |
| [`operator-test`](examples/operator-test) | The operator pattern end to end on one cluster |
| [`s3-crr-one-direction`](examples/s3-crr-one-direction) / [`s3-crr-bidirectional`](examples/s3-crr-bidirectional) | Cross-region replication between two clusters |

### ARTESCA

| Example | Shows |
|---|---|
| [`artesca-account`](examples/artesca-account) | An account and its S3 keys |
| [`artesca-application-bucket`](examples/artesca-application-bucket) | A versioned, encrypted bucket with expiration and cleanup rules |
| [`artesca-application-identity`](examples/artesca-application-identity) | A user with read-write access to one bucket |
| [`artesca-compliance-bucket`](examples/artesca-compliance-bucket) | A bucket with object lock and a default retention |
| [`artesca-group-access`](examples/artesca-group-access) | Application users, plus a group with read-only access to a shared bucket |
| [`artesca-terraform-state-bootstrap`](examples/artesca-terraform-state-bootstrap) | A dedicated account, state bucket and state user |

### ARTESCA + Scality S3 (both providers)

| Example | Shows |
|---|---|
| [`artesca-edge-to-ring-s3`](examples/artesca-edge-to-ring-s3) | An ARTESCA bucket replicated to a Scality S3 bucket, through a location or CRR over STS |
| [`artesca-ring-s3-backed-bucket`](examples/artesca-ring-s3-backed-bucket) | An ARTESCA bucket whose data is stored in a Scality S3 bucket |
| [`artesca-storage-location`](examples/artesca-storage-location) | An ARTESCA location backed by a Scality S3 bucket |
| [`artesca-tiered-bucket`](examples/artesca-tiered-bucket) | An ARTESCA bucket whose objects move to a Scality S3 bucket after a number of days |

## Repository layout

```
modules/
├── scality-<name>/   # Scality S3 modules
└── artesca-<name>/   # ARTESCA modules

examples/<name>/      # Runnable examples; hybrid ones use both providers
docs/          # Cross-module guidance
```

## Consuming a module

Published to the Terraform and OpenTofu registries as
**`cmrh/storage/scality`**. Each use-case module is a registry *submodule*,
addressed with the `//modules/<product>-<name>` path. Pin a version:

```hcl
module "tofu_state" {
  source  = "cmrh/storage/scality//modules/scality-terraform-state-bootstrap"
  version = "~> 1.4"

  account_email = "platform@example.com"
  bucket_name   = "platform-tofu-state"
}
```

`terraform` resolves this from `registry.terraform.io` and `tofu` from
`registry.opentofu.org` — the collection is published to both. For a specific
commit or branch, or without the registry, a Git source works too:

```hcl
source = "git::https://github.com/cmrh/terraform-scality-storage.git//modules/scality-terraform-state-bootstrap?ref=v1.4.0"
```

**Air-gapped or restricted networks** (no registry or GitHub access) need both
the modules and the provider served locally — see
[docs/offline-install.md](docs/offline-install.md).

**Accounts, buckets and users created by hand** can be adopted into the modules without
recreating them — see [docs/adoption.md](docs/adoption.md), or
[docs/artesca-adoption.md](docs/artesca-adoption.md) for ARTESCA.

Each module's `README.md` documents its inputs, outputs, and any provider
quirks relevant to that use case.

## Provider configuration

These modules expect provider configuration to live in the consuming root
module. Example:

```hcl
terraform {
  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.2"
    }
  }
}

provider "scality" {}  # picks up SCALITY_ENDPOINT / SCALITY_ACCESS_KEY / SCALITY_SECRET_KEY env vars
```

ARTESCA modules use the `artesca` provider instead (`cmrh/artesca`,
`~> 1.2`); see its [README](https://github.com/cmrh/terraform-provider-artesca)
for the environment variables it reads. `init` installs only the providers
the modules you call need: `scality-*` modules pull `cmrh/scality`,
`artesca-*` modules pull `cmrh/artesca`, and only configurations that use
both (like the hybrid examples) pull both.

## Contributing

Changes start from an issue. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
workflow and `make check`, [CHANGELOG.md](CHANGELOG.md) for release history,
and [SECURITY.md](SECURITY.md) for reporting vulnerabilities privately.

## License

Apache 2.0 — see [LICENSE](LICENSE).
