resource "artesca_bucket" "this" {
  account_name        = var.account_name
  name                = var.bucket_name
  location_constraint = var.location_constraint
  # null leaves versioning unmanaged; false would suspend it.
  versioning_enabled = var.versioning ? true : null
  force_destroy      = var.force_destroy
}

resource "artesca_bucket_encryption" "this" {
  count = var.sse_algorithm == null ? 0 : 1

  account_name  = var.account_name
  bucket_name   = artesca_bucket.this.name
  sse_algorithm = var.sse_algorithm
}

resource "artesca_bucket_tagging" "this" {
  count = length(var.tags) == 0 ? 0 : 1

  account_name = var.account_name
  bucket_name  = artesca_bucket.this.name
  tags         = var.tags
}

# Bucket-wide cleanup: noncurrent versions, incomplete multipart uploads and
# delete markers. Kept apart from current-version expiration because ARTESCA
# rejects delete-marker removal in a rule that also expires current versions.
resource "artesca_bucket_workflow_expiration" "cleanup" {
  count = (var.noncurrent_version_expiration_days != null || var.abort_incomplete_multipart_upload_days != null || var.expire_delete_markers) ? 1 : 0

  account_name                                   = var.account_name
  bucket_name                                    = artesca_bucket.this.name
  enabled                                        = true
  previous_version_trigger_delay_days            = var.noncurrent_version_expiration_days
  incomplete_multipart_upload_trigger_delay_days = var.abort_incomplete_multipart_upload_days
  expire_delete_markers                          = var.expire_delete_markers ? true : null
}

resource "artesca_bucket_workflow_expiration" "this" {
  count = var.expiration_days == null ? 0 : 1

  account_name                       = var.account_name
  bucket_name                        = artesca_bucket.this.name
  enabled                            = true
  current_version_trigger_delay_days = var.expiration_days

  dynamic "filter" {
    for_each = var.expiration_prefix == null ? [] : [var.expiration_prefix]
    content {
      object_key_prefix = filter.value
    }
  }
}
