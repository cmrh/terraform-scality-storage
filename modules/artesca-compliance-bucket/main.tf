module "bucket" {
  source = "../artesca-application-bucket"

  account_name        = var.account_name
  bucket_name         = var.bucket_name
  object_lock_enabled = true
  sse_algorithm       = var.sse_algorithm
  tags                = var.tags
  force_destroy       = var.force_destroy

  # Locked versions are kept for their retention; don't expire them.
  noncurrent_version_expiration_days     = null
  abort_incomplete_multipart_upload_days = var.abort_incomplete_multipart_upload_days
}

resource "artesca_bucket_object_lock" "this" {
  account_name    = var.account_name
  bucket_name     = module.bucket.bucket_name
  retention_mode  = var.retention_mode
  retention_days  = var.retention_days
  retention_years = var.retention_years

  lifecycle {
    precondition {
      condition     = (var.retention_days != null) != (var.retention_years != null)
      error_message = "Set exactly one of retention_days or retention_years."
    }
  }
}
