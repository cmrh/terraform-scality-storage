resource "scality_bucket" "this" {
  account_access_key  = var.account_access_key
  account_secret_key  = var.account_secret_key
  bucket              = var.bucket_name
  object_lock_enabled = true
  versioning          = true
  tags                = var.tags

  # Import leaves both null: object_lock_enabled would force a replacement, and
  # setting versioning fails on an object-lock bucket (InvalidBucketState).
  # Object lock can't be disabled and keeps versioning on, so ignoring them
  # hides no drift.
  lifecycle {
    ignore_changes = [object_lock_enabled, versioning]
  }
}

resource "scality_bucket_encryption" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket
  sse_algorithm      = var.sse_algorithm
  kms_master_key_id  = var.sse_algorithm == "aws:kms" ? var.kms_master_key_id : null
}

resource "scality_bucket_object_lock" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket
  retention_mode     = var.retention_mode
  retention_days     = var.retention_days
  retention_years    = var.retention_years

  lifecycle {
    precondition {
      condition     = (var.retention_days != null) != (var.retention_years != null)
      error_message = "Provide exactly one of retention_days or retention_years (not both, not neither)."
    }
  }
}

resource "scality_bucket_lifecycle" "this" {
  count = var.abort_incomplete_multipart_upload_days != null ? 1 : 0

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket

  rule {
    id                                     = "abort-incomplete-multipart-uploads"
    status                                 = "Enabled"
    prefix                                 = ""
    abort_incomplete_multipart_upload_days = var.abort_incomplete_multipart_upload_days
  }
}
