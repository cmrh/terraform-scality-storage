# Changelog

All notable changes to this repository are documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
