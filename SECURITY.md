# Security policy

## Reporting a vulnerability

If you find a security vulnerability in these modules, report it privately
through GitHub's [private vulnerability reporting](https://github.com/cmrh/terraform-scality-storage/security/advisories/new).
Don't open a public issue.

Include:

- A description of the vulnerability and its impact
- Which module(s) and version(s) are affected
- Steps to reproduce, ideally with a minimal configuration
- The OpenTofu / Terraform version, the `cmrh/scality` provider version, and
  the Scality cluster version if relevant
- Any suggested mitigation

You'll get an acknowledgement and status updates through the advisory. Please
allow reasonable time for a fix before any public disclosure.

Vulnerabilities in the provider itself belong in
[cmrh/terraform-provider-scality](https://github.com/cmrh/terraform-provider-scality/security/policy).

## Supported versions

Security fixes are issued for the latest minor release. Once a release line is
superseded, upgrade to receive fixes.
