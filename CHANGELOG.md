# Changelog

All notable changes to this repository are documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

No release has been published yet. Pre-migration tags are being retired (#5).

### Added
- `access-log-bucket` module and `examples/scality/access-logging`: a server
  access log bucket with delivery policy, encryption and retention, plus
  logging on source buckets. Requires cmrh/scality 1.1.5. (#16)
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
- CI validates every module and example with both OpenTofu and Terraform, on
  GitHub-hosted runners, with pinned tool versions. (#2)
- `delegated-admin-role` README: compromise guidance no longer claims that
  rotating the key or deleting the user invalidates leaked keys, which was
  untested. It now lists only the actions. (#9)
