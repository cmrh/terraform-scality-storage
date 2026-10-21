# Scality Terraform Modules

Composite Terraform/OpenTofu modules for production deployments on Scality
storage. Built on the
[`scality`](https://github.com/cmrh/terraform-provider-scality) provider
(S3C / RING) and the
[`artesca`](https://github.com/cmrh/terraform-provider-artesca)
provider (ARTESCA).

> Compatible with both Terraform and [OpenTofu](https://opentofu.org/). Examples in this repo use `terraform`; substitute `tofu` if you use OpenTofu — the commands, syntax, and state files are identical.

## Module catalog

### Scality (S3C / RING)

| Module | Status | Purpose |
|---|---|---|
| [`terraform-state-bootstrap`](modules/scality-terraform-state-bootstrap) | Available | Dedicated account + bucket for OpenTofu/Terraform state |
| [`scality-account-management`](modules/scality-account-management) | Available | Tenant account (Console-UI or headless) + stable access key |
| [`application-identity`](modules/scality-application-identity) | Available | IAM user + access key + canned policy preset (read-only / read-write / bucket-admin) or custom JSON |
| [`account-operator`](modules/scality-account-operator) | Available | Operator user (`iam:* + s3:*`) — recommended caller for downstream wrapper modules |
| [`delegated-admin-role`](modules/scality-delegated-admin-role) | Available | Sub-account role a single management-account user assumes (provider `assume_role`) to manage the sub-account's buckets and IAM |
| [`application-bucket`](modules/scality-application-bucket) | Available | Bucket + encryption + versioning + lifecycle hygiene |
| [`access-log-bucket`](modules/scality-access-log-bucket) | Available | Log bucket + delivery policy + retention, and access logging on source buckets |
| [`compliance-bucket`](modules/scality-compliance-bucket) | Available | Bucket + object lock (GOVERNANCE / COMPLIANCE) + retention period |
| [`s3-crr`](modules/scality-s3-crr) | Available | Cross-region replication (one-direction or bidirectional) between two clusters |
| [`ring-replication-target`](modules/scality-ring-replication-target) | Available | Versioned bucket + least-privilege user for an ARTESCA RING location to replicate into |

### ARTESCA

| Module | Status | Purpose |
|---|---|---|
| [`edge-replication`](modules/artesca-edge-replication) | Available | Account + users + bucket replicated to a RING location (pair with `ring-replication-target`; see [`examples/artesca-edge-to-ring`](examples/artesca-edge-to-ring)) |
| [`artesca-account-management`](modules/artesca-account-management) | Available | Account + S3 keys |
| [`artesca-application-identity`](modules/artesca-application-identity) | Available | IAM user + access key + policy preset (read-only / read-write / bucket-admin) or custom JSON |
| `storage-location` | Planned | Backend location + optional endpoint |
| `application-bucket` | Planned | Bucket + optional expiration workflow |
| `tiered-bucket` | Planned | Bucket + transition workflow |
| `replication-stream` | Planned | Overlay/location-based replication |
| `terraform-state-bootstrap` | Planned | State bucket on ARTESCA |

### Hybrid (both providers)

| Module | Status | Purpose |
|---|---|---|
| `ring-backed-artesca-location` | Planned | Use S3C/RING as an ARTESCA backend location |

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
  version = "~> 1.0"

  account_email = "platform@example.com"
  bucket_name   = "platform-tofu-state"
}
```

`terraform` resolves this from `registry.terraform.io` and `tofu` from
`registry.opentofu.org` — the collection is published to both. For a specific
commit or branch, or without the registry, a Git source works too:

```hcl
source = "git::https://github.com/cmrh/terraform-scality-storage.git//modules/scality-terraform-state-bootstrap?ref=v1.1.0"
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

For ARTESCA modules, also declare the `artesca` provider — see the
[provider README](https://github.com/cmrh/terraform-provider-artesca)
for required environment variables.

Air-gapped or dark-site deployments that can't reach the public registry at
init time: see [docs/offline-install.md](docs/offline-install.md) for setting
up a provider mirror.

## Contributing

Changes start from an issue. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
workflow and `make check`, [CHANGELOG.md](CHANGELOG.md) for release history,
and [SECURITY.md](SECURITY.md) for reporting vulnerabilities privately.

## License

Apache 2.0 — see [LICENSE](LICENSE).
