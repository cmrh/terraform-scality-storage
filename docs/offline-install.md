# Offline / dark-site installation

Consuming these modules on a dark site — an air-gapped cluster, or any network
with no egress to the public registries or `github.com` — means `init` has to
resolve **two independent things locally**: the **modules** themselves, and the
**`cmrh/scality` provider** they require. Vendoring the modules is not enough on
its own; the provider still has to come from somewhere `init` can reach. This
document covers both.

> Commands below show `tofu`; `terraform` works identically — same
> subcommands, same CLI-config blocks, only the binary name differs. Use
> whichever you run.

---

## Modules

The modules are published to the Terraform and OpenTofu registries as
`cmrh/storage/scality`, but a dark site can reach neither the registry nor
`github.com`. Two offline options:

### Vendored (local path)

Copy this repository into the consuming configuration's tree — e.g. under
`vendor/` — and reference each module by **local path**. Local paths take no
`version` argument; the version is whatever tag or commit you vendored:

```hcl
module "tofu_state" {
  source = "./vendor/terraform-scality-storage/modules/scality-terraform-state-bootstrap"

  account_email = "platform@example.com"
  bucket_name   = "platform-tofu-state"
}
```

To move to a new version, re-vendor at the tag you want.

### Internal Git mirror

If the site can reach an internal Git server, mirror the repository there and
point a Git source at that host:

```hcl
source = "git::https://git.internal.example.com/mirror/terraform-scality-storage.git//modules/scality-terraform-state-bootstrap?ref=v1.0.0"
```

---

## Providers

The modules declare the
[`cmrh/scality`](https://registry.opentofu.org/providers/cmrh/scality) provider.
A normal `init` pulls it from the registry over the internet; a dark site can't.
Instead of carrying the binary around by hand (the old `dev_overrides`
workaround), use a **provider mirror**: a registry-protocol-compatible copy that
`init` resolves locally, with the lockfile keeping versions and checksums pinned
so an offline init is byte-for-byte identical to an online one.

Use the **filesystem mirror** unless you're serving many machines or CI runners,
in which case stand up a **network mirror**.

### Filesystem mirror (recommended; no infrastructure)

A directory of provider archives, populated on a connected machine and copied
into the dark site. No server, no daemon.

**1. On a machine _with_ internet access** — create a throwaway config that
requires the provider (or `cd` into any module here), then mirror it, including
every platform your dark-site hosts and CI runners actually run:

```hcl
# mirror-stub/versions.tf
terraform {
  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
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

`./scality-mirror` now holds `registry.opentofu.org/cmrh/scality/...` with the
provider zips and their `*.json` index files.

**2. Move the mirror into the dark site** — copy the `scality-mirror/` directory
across the air-gap (artifact repo, USB, internal package store) to somewhere
stable, e.g. `/opt/tf-mirror`.

**3. Point the CLI at the mirror** — create a CLI config file on each host (or
ship one centrally) and export `TF_CLI_CONFIG_FILE`:

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

**4. Init offline:**

```sh
tofu init   # resolves cmrh/scality from the mirror, never touches the network
```

### Network mirror (for fleets / CI)

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

The served directory is exactly what `tofu providers mirror` produces above —
generate once, host once, every consumer inits against it.

### Pinning and the lockfile

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
