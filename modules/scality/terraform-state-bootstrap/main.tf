resource "scality_console_account" "state" {
  count = var.console_login ? 1 : 0

  account_name             = var.account_name
  email                    = var.account_email
  generate_random_password = true
}

resource "scality_account" "state" {
  count = var.console_login ? 0 : 1

  name              = var.account_name
  email_address     = var.account_email
  custom_attributes = var.account_attributes
}

# Layered stable key — only when using the Console resource (its bootstrap
# key belongs to the UI lifecycle). The IAM (scality_account) bootstrap
# key is already Terraform-owned and used directly.
resource "scality_account_access_key" "stable" {
  count = var.console_login ? 1 : 0

  account_access_key = scality_console_account.state[0].access_key
  account_secret_key = scality_console_account.state[0].secret_key
}

locals {
  ak = var.console_login ? scality_account_access_key.stable[0].access_key : scality_account.state[0].access_key
  sk = var.console_login ? scality_account_access_key.stable[0].secret_key : scality_account.state[0].secret_key
}

resource "scality_bucket" "state" {
  account_access_key = local.ak
  account_secret_key = local.sk
  bucket             = var.bucket_name
  versioning         = true
  tags               = var.tags
}

resource "scality_bucket_encryption" "state" {
  account_access_key = local.ak
  account_secret_key = local.sk
  bucket             = scality_bucket.state.bucket
  sse_algorithm      = var.sse_algorithm
  kms_master_key_id  = var.sse_algorithm == "aws:kms" ? var.kms_master_key_id : null
}

resource "scality_bucket_lifecycle" "state" {
  account_access_key = local.ak
  account_secret_key = local.sk
  bucket             = scality_bucket.state.bucket

  rule {
    id                                     = "abort-incomplete-multipart-uploads"
    status                                 = "Enabled"
    prefix                                 = ""
    abort_incomplete_multipart_upload_days = var.abort_incomplete_multipart_upload_days
  }

  rule {
    id                                 = "expire-noncurrent-state-versions"
    status                             = "Enabled"
    prefix                             = ""
    noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
  }
}
