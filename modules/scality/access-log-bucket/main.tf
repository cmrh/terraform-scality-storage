locals {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowAccessLogDelivery"
      Effect    = "Allow"
      Principal = { AWS = var.log_delivery_principal }
      Action    = "s3:PutObject"
      Resource  = "arn:aws:s3:::${var.bucket_name}/*"
    }]
  })
}

resource "scality_bucket" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = var.bucket_name
  versioning         = false
  tags               = var.tags

  lifecycle {
    precondition {
      condition     = !contains(keys(var.logged_buckets), var.bucket_name)
      error_message = "bucket_name can't be in logged_buckets: logging a bucket into itself creates a feedback loop."
    }
  }
}

resource "scality_bucket_policy" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket
  policy             = local.policy
}

resource "scality_bucket_encryption" "this" {
  count = var.sse_algorithm == null ? 0 : 1

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket
  sse_algorithm      = var.sse_algorithm
  kms_master_key_id  = var.sse_algorithm == "aws:kms" ? var.kms_master_key_id : null
}

resource "scality_bucket_lifecycle" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = scality_bucket.this.bucket

  rule {
    id              = "expire-access-logs"
    status          = "Enabled"
    prefix          = ""
    expiration_days = var.retention_days
  }
}

resource "scality_bucket_logging" "this" {
  for_each = var.logged_buckets

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = each.key
  target_bucket      = scality_bucket.this.bucket
  target_prefix      = each.value

  # Without the policy, delivery fails silently.
  depends_on = [scality_bucket_policy.this]
}
