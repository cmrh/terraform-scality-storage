# Releasing

A release of this repository is a **git tag**. There are no build artifacts.
The Terraform and OpenTofu registries serve the tagged source directly, so
every submodule under `modules/` shares the one version.

## Version numbering

Follow [Semantic Versioning](https://semver.org/). Tags are `vMAJOR.MINOR.PATCH`,
always including the patch number (`v1.2.0`, not `v1.2`).

| Bump | When |
|---|---|
| **Patch** (`v1.2.1`) | Bug fixes, documentation, no interface change |
| **Minor** (`v1.3.0`) | New modules, new optional inputs, new outputs. Also raised minimum provider versions, and new defaults that add resources to existing deployments; the CHANGELOG lists each under **Changed** |
| **Major** (`v2.0.0`) | Breaking changes: removed or renamed inputs, outputs or module paths, and anything that forces replacement of existing resources on upgrade |

Pre-releases use a suffix (`v1.3.0-rc1`).

## Release flow

1. **Check `main` is green**: every required check, including both engines
   (`validate (tofu)`, `validate (terraform)`). The integration workflow is
   not a release gate.
2. **Update `CHANGELOG.md`:** move `[Unreleased]` into a new
   `## [X.Y.Z] - YYYY-MM-DD` section, through a normal PR.
3. **Tag the merge commit** on `main` and push the tag:

   ```bash
   git switch main && git pull --ff-only
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```

4. **Create the GitHub release** from the tag, using the CHANGELOG section as
   the notes.

## Rules

- **Tags are immutable.** Never move or delete a released tag. Registries and
  consumers treat a published version as fixed. To fix a bad release, cut a
  new patch release.
- **Only tag commits on `main`** that passed CI.

## Registry publishing

The module address is `cmrh/storage/scality` on both the Terraform and
OpenTofu registries. After pushing a tag, check that the new version is listed
on both before announcing it.
