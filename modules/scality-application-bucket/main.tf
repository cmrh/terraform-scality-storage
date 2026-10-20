locals {
  # Build the lifecycle rule list from the three baseline knobs. Each rule
  # takes the full provider schema with null for unused actions, so the
  # dynamic block below renders a clean per-rule body.
  rule_specs = [
    for spec in [
      {
        condition = var.abort_incomplete_multipart_upload_days != null
        rule = {
          id                                     = "abort-incomplete-multipart-uploads"
          status                                 = "Enabled"
          prefix                                 = ""
          expiration_days                        = null
          noncurrent_version_expiration_days     = null
          abort_incomplete_multipart_upload_days = var.abort_incomplete_multipart_upload_days
        }
      },
      {
        condition = var.noncurrent_version_expiration_days != null
        rule = {
          id                                     = "expire-noncurrent-versions"
          status                                 = "Enabled"
          prefix                                 = ""
          expiration_days                        = null
          noncurrent_version_expiration_days     = var.noncurrent_version_expiration_days
          abort_incomplete_multipart_upload_days = null
        }
      },
      {
        condition = var.expiration_days != null
        rule = {
          id                                     = "expire-current-objects"
          status                                 = "Enabled"
          prefix                                 = ""
          expiration_days                        = var.expiration_days
          noncurrent_version_expiration_days     = null
          abort_incomplete_multipart_upload_days = null
        }
      },
    ] : spec.rule if spec.condition
  ]
}

resource "scality_bucket" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = var.bucket_name
  versioning         = var.versioning
  tags               = var.tags
}

resource "scality_bucket_encryption" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket
  sse_algorithm      = var.sse_algorithm
  kms_master_key_id  = var.sse_algorithm == "aws:kms" ? var.kms_master_key_id : null
}

resource "scality_bucket_lifecycle" "this" {
  count = length(local.rule_specs) > 0 ? 1 : 0

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket

  dynamic "rule" {
    for_each = local.rule_specs
    content {
      id                                     = rule.value.id
      status                                 = rule.value.status
      prefix                                 = rule.value.prefix
      expiration_days                        = rule.value.expiration_days
      noncurrent_version_expiration_days     = rule.value.noncurrent_version_expiration_days
      abort_incomplete_multipart_upload_days = rule.value.abort_incomplete_multipart_upload_days
    }
  }
}
