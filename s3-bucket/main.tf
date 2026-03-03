# S3 Bucket Module
# Creates and configures S3 buckets with all supported Scality operations

# Create the S3 bucket
resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name      = var.bucket_name
      ManagedBy = "OpenTofu"
    }
  )
}

# Configure bucket versioning
resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning_enabled != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

# Configure bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_algorithm
      kms_master_key_id = var.encryption_algorithm == "aws:kms" ? var.kms_master_key_id : null
    }
  }
}

# Configure bucket ACL
resource "aws_s3_bucket_acl" "this" {
  count  = var.acl != null ? 1 : 0
  bucket = aws_s3_bucket.this.id
  acl    = var.acl

  depends_on = [aws_s3_bucket_ownership_controls.this]
}

# Configure bucket ownership controls
resource "aws_s3_bucket_ownership_controls" "this" {
  count  = var.object_ownership != null ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }
}

# Configure bucket policy
resource "aws_s3_bucket_policy" "this" {
  count  = var.bucket_policy != null ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy
}

# Configure public access block
resource "aws_s3_bucket_public_access_block" "this" {
  count  = var.enable_public_access_block ? 1 : 0
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# Configure CORS
resource "aws_s3_bucket_cors_configuration" "this" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      id              = try(cors_rule.value.id, null)
      allowed_headers = try(cors_rule.value.allowed_headers, null)
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = try(cors_rule.value.expose_headers, null)
      max_age_seconds = try(cors_rule.value.max_age_seconds, null)
    }
  }
}

# Configure website hosting
resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.enable_website_hosting ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "index_document" {
    for_each = var.website_index_document != null ? [var.website_index_document] : []
    content {
      suffix = index_document.value
    }
  }

  dynamic "error_document" {
    for_each = var.website_error_document != null ? [var.website_error_document] : []
    content {
      key = error_document.value
    }
  }

  dynamic "routing_rule" {
    for_each = var.website_routing_rules
    content {
      condition {
        http_error_code_returned_equals = try(routing_rule.value.condition.http_error_code_returned_equals, null)
        key_prefix_equals               = try(routing_rule.value.condition.key_prefix_equals, null)
      }
      redirect {
        host_name               = try(routing_rule.value.redirect.host_name, null)
        http_redirect_code      = try(routing_rule.value.redirect.http_redirect_code, null)
        protocol                = try(routing_rule.value.redirect.protocol, null)
        replace_key_prefix_with = try(routing_rule.value.redirect.replace_key_prefix_with, null)
        replace_key_with        = try(routing_rule.value.redirect.replace_key_with, null)
      }
    }
  }
}

# Configure object lock
resource "aws_s3_bucket_object_lock_configuration" "this" {
  count  = var.enable_object_lock ? 1 : 0
  bucket = aws_s3_bucket.this.id

  object_lock_enabled = "Enabled"

  dynamic "rule" {
    for_each = var.object_lock_retention != null ? [var.object_lock_retention] : []
    content {
      default_retention {
        mode  = rule.value.mode
        days  = try(rule.value.days, null)
        years = try(rule.value.years, null)
      }
    }
  }
}

# Note: Replication configuration is handled by the s3-crr module
# Note: Bucket notifications can be added separately if needed
