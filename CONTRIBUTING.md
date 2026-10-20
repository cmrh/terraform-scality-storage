# Contributing

Thanks for your interest in improving these modules.

## Workflow: issue → branch → PR

Every change starts from a GitHub issue.

1. **Open an issue** (bug report or feature request) and agree on the
   approach there before writing code.
2. **Create a branch** named `<type>/<issue>-<short-slug>`, for example
   `feat/12-bucket-logging` or `fix/15-crr-destroy-order`. Types: `feat`,
   `fix`, `docs`, `ci`, `chore`, `refactor`.
3. **Commit** using [Conventional Commits](https://www.conventionalcommits.org/)
   (`feat: …`, `fix: …`, `docs: …`), and reference the issue (`Refs #12`).
4. **Open one PR per issue** against `main`. Fill in the PR template, and put
   `Closes #12` in the description.
5. **Keep CI green.** All checks must pass before merge.

For security issues, see [SECURITY.md](SECURITY.md). Don't open a public issue.

## Development setup

You'll need:

- [OpenTofu](https://opentofu.org/) **and** [Terraform](https://www.terraform.io/):
  every module and example must work with both
- [tflint](https://github.com/terraform-linters/tflint)
- [actionlint](https://github.com/rhysd/actionlint) (for workflow changes)
- A Scality cluster, for anything beyond static checks

The modules use the published `cmrh/scality` provider from the public
registries. `init` resolves it normally, so no local overrides are needed.

## Checks

Run the same checks CI runs:

```bash
make check
```

That's formatting, tflint, actionlint, then `validate` for every module and
example under **both** engines. The individual targets:

| Target | What it does |
|---|---|
| `make fmt` | Format all `.tf` files in place |
| `make fmt-check` | Fail on unformatted files (`ENGINE=terraform` to use Terraform) |
| `make lint` | tflint, recursively |
| `make actionlint` | Lint GitHub Actions workflows |
| `make validate ENGINE=tofu` | Validate with one engine |
| `make validate-all` | Validate with both engines |

Modules that declare `configuration_aliases` (e.g. `s3-crr`) are validated
through their examples, because Terraform can't validate them standalone.

## Engine parity

Nothing may depend on differences between OpenTofu and Terraform. If a feature
exists in only one engine (for example, `for_each` on provider blocks), treat
it as unavailable.

## Module conventions

- **Layout:** `modules/<product>-<name>/` with `main.tf`, `variables.tf`,
  `outputs.tf`, `versions.tf` and `README.md`. Add a matching example under
  `examples/<product>/<name>/` for anything non-trivial.
- **Every variable and output** has a `type` (variables) and a `description`
  of one or two sentences.
- **No provider blocks inside modules.** Provider configuration belongs to the
  caller. Modules that need several provider configurations declare
  `configuration_aliases`.
- **The README** documents what the module creates, usage, inputs, outputs and
  caveats. Caveats state only behavior that has been tested.
- **No credentials in any file** that could end up in git. Use environment
  variables (`SCALITY_*` or `TF_VAR_*`). Never commit `.tfvars` files.
- **Test changes on a real cluster** for anything that creates resources, and
  note the environment in the PR.
- **Update `CHANGELOG.md`** under `[Unreleased]`.
