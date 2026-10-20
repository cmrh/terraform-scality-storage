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

# Layered stable key — Terraform-owned, independent of the UI lifecycle.
# Only when using the Console resource (its bootstrap key belongs to the UI).
resource "scality_account_access_key" "stable" {
  count = var.console_login ? 1 : 0

  account_access_key = scality_console_account.this[0].access_key
  account_secret_key = scality_console_account.this[0].secret_key
}
