# Changelog

All notable changes to this repository are documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- `RELEASING.md`: a minor release may raise minimum provider versions and add
  default resources, listed in the CHANGELOG; a major release is for removed
  or renamed inputs, outputs or module paths, and replacements on upgrade.

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
