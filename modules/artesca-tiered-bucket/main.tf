module "bucket" {
  source = "../artesca-application-bucket"

  account_name  = var.account_name
  bucket_name   = var.bucket_name
  sse_algorithm = var.sse_algorithm
  tags          = var.tags
  force_destroy = var.force_destroy
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
