# Changelog

All notable changes to this repository are documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `scripts/scality-adopt.sh` adopts groups into `scality-group-access`, with
  their members and managed policies. A group owns the account policies
  attached only to it; others are attached by ARN. (#74)
- `scality-application-bucket` and `scality-compliance-bucket`: optional
  `bucket_policy` input. `scripts/scality-adopt.sh` adopts each bucket's
  policy into it. (#77)
- `scripts/scality-adopt.sh` adopts each bucket that receives server access
  logs into `scality-access-log-bucket`, with the logging configuration of
  the buckets that log to it. (#78)
- `scality-application-identity`: `policies` input, for further inline
  policies by name. A user can also have no policy: with no `bucket_arns`,
  `policy_document` or `policies`, none is created, where plan used to fail.
  New `policy_names` output. `scripts/scality-adopt.sh` adopts users with any
  number of inline policies. (#79)
- `scality-application-identity`: `policy_arns` input, attaching managed
  policies to the user, and a `policy_arns` output.
  `scripts/scality-adopt.sh` adopts the managed policies attached to users.
  (#81)
- `artesca-application-identity`: `policies` input for further inline
  policies by name, and `policy_arns` for managed policies. A user can have
  no policy: with no `bucket_arns`, `policy_document`, `policies` or
  `policy_arns`, none is created, where plan used to fail. New
  `policy_names` and `policy_arns` outputs. (#91)
- `artesca-application-bucket` and `artesca-compliance-bucket`: optional
  `bucket_policy` input. (#91)
- `artesca-group-access` module and `examples/artesca-group-access`: an IAM
  group with managed policies attached, from JSON documents or existing
  ARNs, and its members. Includes import IDs for adopting an existing group.
  (#96)
- `scripts/artesca-adopt.sh` and `docs/artesca-adoption.md`: adopt the
  buckets, users and groups of an existing ARTESCA account into the artesca
  modules with `import {}` blocks, without recreating them. The script signs
  in with the artesca provider's settings. (#82)
- `artesca-tiered-bucket`: `abort_incomplete_multipart_upload_days`,
  `expire_delete_markers` and `bucket_policy`, passed to its bucket. (#82)

### Changed
- **Breaking: names that said "ring" now say "ring-s3",** as ARTESCA's
  RING S3 location type does. RING is the store under Scality S3. Update
  `source` addresses and inputs (#100):
  - `modules/scality-ring-replication-target` → `modules/scality-ring-s3-target`
  - `examples/artesca-edge-to-ring` → `examples/artesca-edge-to-ring-s3`, and
    `examples/artesca-ring-backed-bucket` →
    `examples/artesca-ring-s3-backed-bucket`
  - `artesca-edge-replication` inputs `ring_endpoint`, `ring_bucket_name`,
    `ring_access_key`, `ring_secret_key`, `ring_sts_endpoint` and
    `ring_role_arn` → `ring_s3_*`
  - The examples' `ring_*` variables and outputs → `ring_s3_*`
  - Docs say Scality S3 for the S3 service, and RING S3 location for the
    ARTESCA location type.
- Docs site: examples are grouped by provider (Scality S3, ARTESCA, and
  ARTESCA + Scality S3), guides and pointers have their own sections, and
  each section has a tab. Module and example pages are titled by directory
  name, and the theme uses an indigo palette. The README lists the examples
  the same way. (#99)
- Usage snippets and the module pin `scripts/scality-adopt.sh` writes use
  `~> 1.4`, the first release on cmrh/scality 1.2. (#75)
- `scality-application-bucket`, `scality-compliance-bucket`,
  `scality-access-log-bucket` and `scality-terraform-state-bootstrap` leave
  the lifecycle rule prefix unset instead of `""`, so an imported lifecycle
  plans no change. Existing deployments plan a one-off in-place update of
  the lifecycle that leaves the rules unchanged. (#78)

### Removed
- The integration suite (`integration.yml`, `make integration`) and the
  self-hosted runner guard (`make runner-guard`). The provider acceptance
  suites already test each resource against live clusters before every
  provider release; module behaviour is lab-tested when a module changes.
  (#76)

### Fixed
- `scality-account-management` and `scality-terraform-state-bootstrap`: with
  `account_credentials`, destroy could delete the account before the key
  created from it, and fail. The key now depends on the account. (#80)
- `scripts/scality-adopt.sh`: `--account-module NAME` makes each generated
  call depend on the account module adopted in the same configuration, so
  destroy deletes the buckets, users and groups before the account. (#80)
- `scality-account-management` and `scality-terraform-state-bootstrap`: with
  `console_login = true` (the default), `account_id` returned the account
  name. It now returns the account ID in both modes. In
  `scality-account-management`, `account_arn` and `canonical_id` are now set
  in both modes, where they used to be null with `console_login = true`.
  (#93)
- `scripts/scality-adopt.sh` formats `adopt.tf` with `tofu fmt` or
  `terraform fmt`, so it no longer needs a separate `fmt` run. It now
  requires OpenTofu or Terraform on the path. (#79)

## [1.4.0] - 2026-11-02

### Added
- `scality-group-access`: an IAM group with managed policies attached, from
  JSON documents or existing ARNs, and optionally its members. Includes
  `examples/group-access` and import IDs for adopting an existing group.
  Requires cmrh/scality 1.2. (#67)

### Changed
- Every scality module and example requires cmrh/scality 1.2, which records
  versioning, tags, object lock and `external_account_id` on import, ignores
  formatting-only policy differences, and updates resources in place when
  their account credentials change to another key of the same account. (#71)
- `scality-compliance-bucket` no longer ignores changes to
  `object_lock_enabled` and `versioning`. A bucket imported with an earlier
  release plans a one-off in-place `versioning = true` on the first apply.
  (#71)
- `docs/adoption.md`: `external_account_id` can be set when adopting an
  account, and existing groups can be imported into `scality-group-access`
  so destroy removes them. (#71)

### Fixed
- `scality-account-management`: the `external_account_id` example used a
  value that is rejected. The value becomes the account ID, as a 12-digit
  number; the example and input description say so. (#69)

## [1.3.0] - 2026-10-28

### Added
- Documentation site on GitHub Pages, built from the module and example
  READMEs and `docs/`, deployed on each release tag. Adds pointer pages on
  state locking and secrets, including OpenTofu state encryption.
- `scripts/scality-adopt.sh` and `docs/adoption.md`: adopt buckets and users
  created by hand into the bucket and identity modules with `import {}`
  blocks, without recreating them. (#61)
- `scality-account-management` and `scality-terraform-state-bootstrap`:
  `account_credentials` input for adopting an existing account. The module
  creates a Terraform-owned key from the given key, since import can't recover
  the account's own. Documented in `docs/adoption.md`. (#62)

### Changed
- `RELEASING.md`: a minor release may raise minimum provider versions and add
  default resources, listed in the CHANGELOG; a major release is for removed
  or renamed inputs, outputs or module paths, and replacements on upgrade.
- Docs: removed repeated text across module and example READMEs. The
  `s3-crr-*` examples follow the same layout as the others, and the PR
  template's breaking-change definition matches `RELEASING.md`.

### Fixed
- `scality-compliance-bucket` no longer plans a replacement of an imported
  bucket, or fails to apply with `InvalidBucketState`. It ignores changes to
  `object_lock_enabled` and `versioning`, which import leaves unset and which
  object lock keeps on. (#61)

## [1.2.0] - 2026-10-22

### Added
- `artesca-application-bucket`: `noncurrent_version_expiration_days`,
  `abort_incomplete_multipart_upload_days` and `expire_delete_markers`. (#48)
- `artesca-tiered-bucket`: `noncurrent_transition_days` moves noncurrent
  versions too, and `noncurrent_version_expiration_days` is passed through.
  (#50)
- `artesca-compliance-bucket` module and `examples/artesca-compliance-bucket`:
  a bucket with object lock and a default retention. (#49)
- `artesca-application-bucket`: `object_lock_enabled`. (#49)
- `artesca-edge-replication`: `mode = "crr"` replicates over STS through a
  destination role on RING, and `examples/artesca-edge-to-ring` can run in
  either mode. `scality-ring-replication-target` gains `purpose = "crr"`: a
  key that can only assume the role, and the role, which can only write
  replicas to the bucket. `artesca-edge-replication` now requires
  cmrh/artesca 1.2. (#42)

### Changed
- Docs reviewed against tested behaviour across all modules, examples and
  repository docs:
  - Usage snippets pin the module at `~> 1.2`; the root module also declares
    `cmrh/artesca`, so the registry lists both providers.
  - `docs/offline-install.md` covers both providers, and its filesystem
    mirror, network mirror and lockfile steps were verified with both
    engines.
  - Corrected: role deletion outside Terraform in `scality-delegated-admin-role`
    (the next plan recreates it), `console_login` changes in
    `scality-terraform-state-bootstrap` (the apply fails; pick the mode before
    the first apply) and `scality-account-management` (the account is
    replaced), plus stale paths, names and snippets.
  - CONTRIBUTING, SECURITY and the issue templates cover the ARTESCA provider.
- `artesca-application-bucket` adds a cleanup rule by default: noncurrent
  versions are deleted after 90 days and incomplete multipart uploads aborted
  after 7, matching `scality-application-bucket`. It, `artesca-tiered-bucket`
  and `artesca-terraform-state-bootstrap` require cmrh/artesca 1.2. (#48)

## [1.1.0] - 2026-10-21

### Added
- `artesca-account-management` module and `examples/artesca-account`: an
  ARTESCA account and its S3 keys. (#35)
- `artesca-application-identity` module and
  `examples/artesca-application-identity`: an IAM user with an access key and
  a preset or custom policy over specific buckets. (#36)
- `artesca-application-bucket` module and `examples/artesca-application-bucket`:
  a bucket with versioning, encryption, optional tags and an optional
  expiration rule. (#37)
- `artesca-storage-location` module and `examples/artesca-storage-location`:
  an ARTESCA location backed by a RING bucket, with an optional S3 endpoint.
  (#38)
- `artesca-tiered-bucket` module and `examples/artesca-tiered-bucket`: a
  bucket whose objects move to another location after a number of days.
  (#39)
- `artesca-storage-location`: `versity-tape` type for a cold Versity tape
  archive location; its endpoint must be `https://`. (#39)
- `scality-ring-replication-target`: `purpose` input. `tiering` gives the key
  read and delete rights for ARTESCA transitions; `replication` (default)
  keeps the write-only key. (#39)
- `artesca-terraform-state-bootstrap` module and
  `examples/artesca-terraform-state-bootstrap`: a dedicated account, a
  versioned and encrypted state bucket, and a user that can read and write
  only that bucket. (#40)
- `examples/artesca-ring-backed-bucket`: an ARTESCA bucket whose data is
  stored in a RING bucket, through a RING location. (#41)

### Changed
- **Every module and example path changed.** Modules and examples now sit
  one level deep, so the Terraform Registry lists them as submodules and
  examples. Update `source` addresses (#30):
  - `//modules/scality/<name>` → `//modules/scality-<name>`
    (`scality-account-management` keeps its name)
  - `//modules/artesca/edge-replication` → `//modules/artesca-edge-replication`
  - `examples/<group>/.../<name>` → `examples/<name>`; the two-stage examples
    are `delegated-admin-bootstrap`/`-managed` and
    `s3-crr-one-direction`/`-bidirectional`
- README links to the providers point at their `cmrh` repositories.
- Docs use `https://` endpoints in examples and recommend TLS for RING
  endpoints.

## [1.0.0] - 2026-10-20

First public release, published to the Terraform and OpenTofu registries as
`cmrh/storage/scality`. (#7)

### Added
- `artesca/edge-replication` and `scality/ring-replication-target` modules,
  and `examples/hybrid/artesca-edge-to-ring`: an ARTESCA bucket replicated to
  a RING bucket through a RING location, using a RING key limited to that
  bucket. (#23)
- `access-log-bucket` module and `examples/scality/access-logging`: a server
  access log bucket with delivery policy, encryption and retention, plus
  logging on source buckets. Requires cmrh/scality 1.1.6. (#16)
- `delegated-admin-role` module: a sub-account IAM role that a single
  management-account user assumes (provider `assume_role`) to manage the
  sub-account's buckets and IAM. (#1)
- `examples/scality/delegated-admin`: two-stage (bootstrap / managed) example
  for delegated administration. (#1)
- Repository governance: `CODEOWNERS`, `SECURITY.md`, `CONTRIBUTING.md`,
  `RELEASING.md`, issue and pull request templates, Dependabot. (#3)
- actionlint for GitHub Actions workflows, in CI and `make check`. (#3)
- Gitleaks secret scanning on push and pull requests, plus a weekly and
  on-demand full-history scan. (#4)

### Changed
- Every module and example requires cmrh/scality 1.1.6 or later. Earlier
  1.1.x releases have bugs these modules hit; on 1.1.5 and earlier,
  `compliance-bucket` fails at plan. (#18)
- CI validates every module and example with both OpenTofu and Terraform, on
  GitHub-hosted runners, with pinned tool versions. (#2)
- `delegated-admin-role` README: compromise guidance no longer claims that
  rotating the key or deleting the user invalidates leaked keys, which was
  untested. It now lists only the actions. (#9)
