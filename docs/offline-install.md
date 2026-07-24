# Offline / dark-site provider installation

These modules declare the [`cmrh/scality`](https://registry.opentofu.org/providers/cmrh/scality)
provider, published on both the OpenTofu and Terraform registries. A normal
`tofu init` (or `terraform init`) pulls it over the internet.

Dark sites — air-gapped clusters, networks with no egress to the public
registries — can't reach the registry at init time. Instead of carrying the
provider binary around by hand (the old `dev_overrides` workaround), use a
**provider mirror**: a registry-protocol-compatible copy of the provider that
init resolves locally. The lockfile keeps versions and checksums pinned, so an
offline init is byte-for-byte identical to an online one.

> Commands below show `tofu`; `terraform` works identically — same
> subcommands, same CLI-config blocks, only the binary name differs. Use
> whichever you run.

Two options below. Use the **filesystem mirror** unless you're serving many
machines or CI runners, in which case stand up a **network mirror**.

---

## Option A — Filesystem mirror (recommended; no infrastructure)

A directory of provider archives, populated on a connected machine and copied
into the dark site. No server, no daemon.

### 1. On a machine *with* internet access

Create a throwaway config that requires the provider (or just `cd` into any
module in this repo), then mirror it — including every platform your dark-site
hosts and CI runners actually run:

```hcl
# mirror-stub/versions.tf
terraform {
  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.0"
    }
  }
}
```

```sh
cd mirror-stub
tofu providers mirror \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  -platform=darwin_arm64 \
  ./scality-mirror
```

`./scality-mirror` now contains
`registry.opentofu.org/cmrh/scality/...` with the provider zips and their
`*.json` index files.

### 2. Move the mirror into the dark site

Copy the `scality-mirror/` directory across your air-gap (artifact repo, USB,
internal package store). Put it somewhere stable, e.g. `/opt/tf-mirror`.

### 3. Point the CLI at the mirror

Create a CLI config file on each dark-site host (or ship one centrally) and
export `TF_CLI_CONFIG_FILE` to point at it:

```hcl
# /opt/tf-mirror/offline.tfrc
provider_installation {
  filesystem_mirror {
    path    = "/opt/tf-mirror/scality-mirror"
    include = ["registry.opentofu.org/cmrh/scality"]
  }
  # Block any accidental reach for the network registry.
  direct {
    exclude = ["registry.opentofu.org/cmrh/scality"]
  }
}
```

```sh
export TF_CLI_CONFIG_FILE=/opt/tf-mirror/offline.tfrc
```

### 4. Init offline

```sh
tofu init   # resolves cmrh/scality from the mirror, never touches the network
```

---

## Option B — Network mirror (for fleets / CI)

If many hosts or pipeline runners need the provider, serve the same mirror
directory over HTTPS as a [provider network
mirror](https://opentofu.org/docs/internals/provider-network-mirror-protocol/)
instead of copying a directory to every machine. Any static file server that
preserves the `tofu providers mirror` layout works.

```hcl
# offline.tfrc
provider_installation {
  network_mirror {
    url = "https://mirror.internal.example.com/providers/"
  }
}
```

```sh
export TF_CLI_CONFIG_FILE=/path/to/offline.tfrc
tofu init
```

The served directory is exactly what `tofu providers mirror` produces in
Option A — generate once, host once, every consumer inits against it.

---

## Pinning and the lockfile

Commit `.terraform.lock.hcl` so the dark site installs the *same* version and
checksums as everywhere else. Record checksums for every platform you run, so
the lock doesn't reject a host architecture the connected machine didn't see:

```sh
tofu providers lock \
  -platform=linux_amd64 \
  -platform=linux_arm64 \
  -platform=darwin_arm64
```

When the provider releases a new version, re-run the `providers mirror` step on
the connected machine, refresh the mirror, and update the lockfile — there's no
other moving part to maintain.
