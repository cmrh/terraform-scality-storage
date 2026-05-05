resource "scality_account" "state" {
  name              = var.account_name
  email_address     = var.account_email
  custom_attributes = var.account_attributes
}

resource "scality_account_access_key" "state" {
  account_access_key = scality_account.state.access_key
  account_secret_key = scality_account.state.secret_key
}

locals {
  ak = scality_account_access_key.state.access_key
  sk = scality_account_access_key.state.secret_key
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
