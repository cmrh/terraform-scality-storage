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
