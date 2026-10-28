# Secrets

*Last checked: 2026-10-28*

Modules that create access keys return them as `sensitive` outputs. That
keeps them out of plan and apply output, and like any Terraform-managed
credential they're stored in state. The options below protect them, lightest
first.

## Limit who can read state

Works with both engines. The `*-terraform-state-bootstrap` modules create a
versioned, encrypted bucket and a user that can reach only that bucket. Keep
state there, and don't commit or share it.

## Encrypt state (OpenTofu)

OpenTofu can encrypt state and plan files before they're written, locally or
to a backend. Anyone who opens the file or the bucket sees only ciphertext.
We've tested this with the S3 backend on Scality storage and with local
state.

Keep the encryption key in a secret manager. Use a passphrase on the machine
only where no secret manager is reachable, such as a laptop used for demos.

### Key in OpenBao (recommended)

With [OpenBao](https://openbao.org/)'s transit engine:

```hcl
terraform {
  encryption {
    key_provider "openbao" "bao" {
      key_name            = "tofu-state"
      transit_engine_path = "/transit"
    }
    method "aes_gcm" "bao" {
      keys = key_provider.openbao.bao
    }
    state {
      method = method.aes_gcm.bao
    }
    plan {
      method = method.aes_gcm.bao
    }
  }
}
```

- An admin creates the transit key and a policy with `update` on
  `transit/datakey/plaintext/<key>` and `transit/decrypt/<key>`.
- Users run `bao login`, then
  `export BAO_ADDR=https://bao.example.com BAO_TOKEN=$(cat ~/.vault-token)`.
  A short-lived login token is enough.

OpenTofu also supports cloud KMS key providers, such as AWS KMS; see the
[state encryption docs](https://opentofu.org/docs/language/state/encryption/).

### Passphrase on a laptop

For demos away from your secret manager, derive the key from a passphrase
kept in the OS keychain:

```hcl
variable "state_passphrase" {
  type      = string
  sensitive = true
}

terraform {
  encryption {
    key_provider "pbkdf2" "local" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "local" {
      keys = key_provider.pbkdf2.local
    }
    state {
      method = method.aes_gcm.local
    }
    plan {
      method = method.aes_gcm.local
    }
  }
}
```

Create the passphrase once, then load it into each new shell:

**macOS** (Keychain):

```bash
security add-generic-password -a "$USER" -s tofu-state -w "$(openssl rand -base64 32)"
export TF_VAR_state_passphrase=$(security find-generic-password -a "$USER" -s tofu-state -w)
```

**Linux** (GNOME Keyring or KWallet, through `secret-tool` from libsecret):

```bash
openssl rand -base64 32 | secret-tool store --label="OpenTofu state" service tofu-state account "$USER"
export TF_VAR_state_passphrase=$(secret-tool lookup service tofu-state account "$USER")
```

Without the passphrase, the state can't be read. Keep a copy in your password
manager.

### Before you switch

- To encrypt existing state, add a `fallback` that reads the old state, apply
  once, then remove the fallback. The
  [state encryption docs](https://opentofu.org/docs/language/state/encryption/)
  show how.
- Terraform can't read encrypted state, so everyone working on that state
  needs OpenTofu.

## Hand keys to applications through a secret store

Write keys to a secret store from the same configuration, rather than
copying them by hand. OpenBao works with the
[Vault provider](https://registry.terraform.io/providers/hashicorp/vault/latest/docs):

```hcl
resource "vault_kv_secret_v2" "app" {
  mount = "secret"
  name  = "apps/billing/s3"
  data_json = jsonencode({
    access_key = module.app.access_key
    secret_key = module.app.secret_key
  })
}
```

Applications then read keys from the store, not from state or outputs.

## Keep keys out of state

Manage users and policies with the modules, and create access keys outside
Terraform. Nothing secret reaches state. In return, you create and rotate
those keys outside Terraform.

## Provider credentials

Give the providers their credentials through environment variables (see
[Provider configuration](../../README.md#provider-configuration)), not
`.tfvars` files or provider blocks, so they don't end up in version control.
