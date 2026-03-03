output "bucket_id" {
  description = "ID of the S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_region" {
  description = "Region where the bucket is created"
  value       = aws_s3_bucket.this.region
}

output "bucket_domain_name" {
  description = "Domain name of the bucket"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "versioning_enabled" {
  description = "Whether versioning is enabled"
  value       = var.versioning_enabled
}

output "encryption_enabled" {
  description = "Whether encryption is enabled"
  value       = var.enable_encryption
}

output "encryption_algorithm" {
  description = "Encryption algorithm used"
  value       = var.enable_encryption ? var.encryption_algorithm : null
}

output "website_endpoint" {
  description = "Website endpoint (if website hosting is enabled)"
  value       = var.enable_website_hosting ? try(aws_s3_bucket_website_configuration.this[0].website_endpoint, null) : null
}

output "website_domain" {
  description = "Website domain (if website hosting is enabled)"
  value       = var.enable_website_hosting ? try(aws_s3_bucket_website_configuration.this[0].website_domain, null) : null
}

output "object_lock_enabled" {
  description = "Whether object lock is enabled"
  value       = var.enable_object_lock
}

output "cors_configured" {
  description = "Whether CORS is configured"
  value       = length(var.cors_rules) > 0
}

output "bucket_tags" {
  description = "Tags applied to the bucket"
  value       = aws_s3_bucket.this.tags
}
