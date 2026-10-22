# Terraform modules for Scality storage

Composite Terraform/OpenTofu modules for production deployments on Scality
storage. Built on the
[`scality`](https://github.com/cmrh/terraform-provider-scality) provider
(S3C / RING) and the
[`artesca`](https://github.com/cmrh/terraform-provider-artesca)
provider (ARTESCA).

> Compatible with both Terraform and [OpenTofu](https://opentofu.org/). Examples use `terraform` or `tofu`; use whichever you run.

## Module catalog

### Scality (S3C / RING)

| Module | Status | Purpose |
|---|---|---|
| [`scality-terraform-state-bootstrap`](modules/scality-terraform-state-bootstrap) | Available | Dedicated account + bucket for OpenTofu/Terraform state |
| [`scality-account-management`](modules/scality-account-management) | Available | Tenant account (Console-UI or headless) + stable access key |
| [`scality-application-identity`](modules/scality-application-identity) | Available | IAM user + access key + canned policy preset (read-only / read-write / bucket-admin) or custom JSON |
| [`scality-account-operator`](modules/scality-account-operator) | Available | Operator user (`iam:* + s3:*`) — recommended caller for downstream wrapper modules |
| [`scality-delegated-admin-role`](modules/scality-delegated-admin-role) | Available | Sub-account role a single management-account user assumes (provider `assume_role`) to manage the sub-account's buckets and IAM |
| [`scality-application-bucket`](modules/scality-application-bucket) | Available | Bucket + encryption + versioning + lifecycle hygiene |
| [`scality-access-log-bucket`](modules/scality-access-log-bucket) | Available | Log bucket + delivery policy + retention, and access logging on source buckets |
| [`scality-compliance-bucket`](modules/scality-compliance-bucket) | Available | Bucket + object lock (GOVERNANCE / COMPLIANCE) + retention period |
| [`scality-s3-crr`](modules/scality-s3-crr) | Available | Cross-region replication (one-direction or bidirectional) between two clusters |
| [`scality-ring-replication-target`](modules/scality-ring-replication-target) | Available | Versioned bucket + least-privilege key for an ARTESCA RING location (replication, tiering or CRR over STS) |

### ARTESCA

| Module | Status | Purpose |
|---|---|---|
| [`artesca-edge-replication`](modules/artesca-edge-replication) | Available | Account + users + bucket replicated to RING, through a RING S3 location or CRR over STS (pair with `scality-ring-replication-target`; see [`examples/artesca-edge-to-ring`](examples/artesca-edge-to-ring)) |
| [`artesca-account-management`](modules/artesca-account-management) | Available | Account + S3 keys |
| [`artesca-application-identity`](modules/artesca-application-identity) | Available | IAM user + access key + policy preset (read-only / read-write / bucket-admin) or custom JSON |
| [`artesca-storage-location`](modules/artesca-storage-location) | Available | RING or Versity tape location + optional endpoint |
| [`artesca-application-bucket`](modules/artesca-application-bucket) | Available | Bucket + versioning + encryption + lifecycle cleanup + optional expiration and object lock |
| [`artesca-tiered-bucket`](modules/artesca-tiered-bucket) | Available | Bucket whose objects move to a RING (warm) or Versity tape (cold) location |
| `replication-stream` | Planned | Overlay/location-based replication |
| [`artesca-compliance-bucket`](modules/artesca-compliance-bucket) | Available | Bucket + object lock + default retention (GOVERNANCE / COMPLIANCE) |
| [`artesca-terraform-state-bootstrap`](modules/artesca-terraform-state-bootstrap) | Available | Dedicated account + versioned state bucket + state user |

### Hybrid (both providers)

| Module | Status | Purpose |
|---|---|---|
| [`artesca-ring-backed-bucket`](examples/artesca-ring-backed-bucket) (example) | Available | ARTESCA bucket whose data is stored in a RING bucket |

## Repository layout

```
modules/
├── scality-<name>/   # S3C / RING modules
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
  version = "~> 1.2"

  account_email = "platform@example.com"
  bucket_name   = "platform-tofu-state"
}
```

`terraform` resolves this from `registry.terraform.io` and `tofu` from
`registry.opentofu.org` — the collection is published to both. For a specific
commit or branch, or without the registry, a Git source works too:

```hcl
source = "git::https://github.com/cmrh/terraform-scality-storage.git//modules/scality-terraform-state-bootstrap?ref=v1.2.0"
```

**Air-gapped or restricted networks** (no registry or GitHub access) need both
the modules and the provider served locally — see
[docs/offline-install.md](docs/offline-install.md).

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
      version = "~> 1.1, >= 1.1.6"
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

Air-gapped or dark-site deployments that can't reach the public registry at
init time: see [docs/offline-install.md](docs/offline-install.md) for setting
up a provider mirror.

## Contributing

Changes start from an issue. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
workflow and `make check`, [CHANGELOG.md](CHANGELOG.md) for release history,
and [SECURITY.md](SECURITY.md) for reporting vulnerabilities privately.

## License

Apache 2.0 — see [LICENSE](LICENSE).
