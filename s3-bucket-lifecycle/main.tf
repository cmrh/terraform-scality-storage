# S3 Bucket Lifecycle Configuration Module
# Manages lifecycle policies for S3 buckets
# Supports: Expiration, NoncurrentVersionExpiration, AbortIncompleteMultipartUpload
# Note: Transition policies are NOT supported by Scality

# Configure bucket lifecycle rules
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = var.bucket_name

  # Dynamic block for lifecycle rules
  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      # Filter configuration
      dynamic "filter" {
        for_each = rule.value.filter != null ? [rule.value.filter] : []
        content {
          # Simple prefix filter
          dynamic "prefix" {
            for_each = try(filter.value.prefix, null) != null && try(filter.value.tag, null) == null && try(filter.value.and, null) == null ? [filter.value.prefix] : []
            content {
              prefix = filter.value.prefix
            }
          }

          # Tag filter
          dynamic "tag" {
            for_each = try(filter.value.tag, null) != null && try(filter.value.and, null) == null ? [filter.value.tag] : []
            content {
              key   = tag.value.key
              value = tag.value.value
            }
          }

          # AND filter (combines prefix and tags)
          dynamic "and" {
            for_each = try(filter.value.and, null) != null ? [filter.value.and] : []
            content {
              prefix = try(and.value.prefix, null)
              tags   = try(and.value.tags, null)
            }
          }
        }
      }

      # Expiration for current versions
      dynamic "expiration" {
        for_each = try(rule.value.expiration, null) != null ? [rule.value.expiration] : []
        content {
          days                         = try(expiration.value.days, null)
          date                         = try(expiration.value.date, null)
          expired_object_delete_marker = try(expiration.value.expired_object_delete_marker, null)
        }
      }

      # Expiration for noncurrent versions
      dynamic "noncurrent_version_expiration" {
        for_each = try(rule.value.noncurrent_version_expiration, null) != null ? [rule.value.noncurrent_version_expiration] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value.noncurrent_days
        }
      }

      # Abort incomplete multipart uploads
      dynamic "abort_incomplete_multipart_upload" {
        for_each = try(rule.value.abort_incomplete_multipart_upload, null) != null ? [rule.value.abort_incomplete_multipart_upload] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value.days_after_initiation
        }
      }
    }
  }

  depends_on = [var.bucket_dependency]
}
