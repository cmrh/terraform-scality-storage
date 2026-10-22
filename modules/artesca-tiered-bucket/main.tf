module "bucket" {
  source = "../artesca-application-bucket"

  account_name  = var.account_name
  bucket_name   = var.bucket_name
  sse_algorithm = var.sse_algorithm

  noncurrent_version_expiration_days = var.noncurrent_version_expiration_days
  tags                               = var.tags
  force_destroy                      = var.force_destroy
}

resource "artesca_bucket_workflow_transition" "this" {
  account_name       = var.account_name
  bucket_name        = module.bucket.bucket_name
  enabled            = true
  location_name      = var.transition_location
  trigger_delay_days = var.transition_days

  dynamic "filter" {
    for_each = var.transition_prefix == null ? [] : [var.transition_prefix]
    content {
      object_key_prefix = filter.value
    }
  }
}

resource "artesca_bucket_workflow_transition" "noncurrent" {
  count = var.noncurrent_transition_days == null ? 0 : 1

  account_name       = var.account_name
  bucket_name        = module.bucket.bucket_name
  enabled            = true
  location_name      = var.transition_location
  apply_to_version   = "noncurrent"
  trigger_delay_days = var.noncurrent_transition_days

  lifecycle {
    precondition {
      condition     = var.noncurrent_version_expiration_days == null || try(var.noncurrent_transition_days < var.noncurrent_version_expiration_days, true)
      error_message = "noncurrent_transition_days must be lower than noncurrent_version_expiration_days, or versions expire before they move."
    }
  }
}
