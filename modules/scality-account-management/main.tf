resource "scality_console_account" "this" {
  count = var.console_login ? 1 : 0

  account_name             = var.account_name
  email                    = var.account_email
  quota                    = var.account_quota
  generate_random_password = true
}

resource "scality_account" "this" {
  count = var.console_login ? 0 : 1

  name                = var.account_name
  email_address       = var.account_email
  quota_max           = var.account_quota
  external_account_id = var.external_account_id
  custom_attributes   = var.account_attributes
}

locals {
  adopted = var.account_credentials != null
}

# Layered stable key — Terraform-owned. Created from the Console's bootstrap
# key (which belongs to the UI), or from account_credentials when adopting an
# existing account (import doesn't recover the account's own keys).
resource "scality_account_access_key" "stable" {
  count = var.console_login || local.adopted ? 1 : 0

  account_access_key = local.adopted ? var.account_credentials.access_key : scality_console_account.this[0].access_key
  account_secret_key = local.adopted ? var.account_credentials.secret_key : scality_console_account.this[0].secret_key

  lifecycle {
    precondition {
      condition     = !(local.adopted && var.console_login)
      error_message = "account_credentials requires console_login = false."
    }
  }
}
