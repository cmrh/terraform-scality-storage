output "bucket_name" {
  value       = module.bucket.bucket_name
  description = "Bucket name."
}

output "bucket_arn" {
  value       = module.bucket.bucket_arn
  description = "Bucket ARN, e.g. for artesca-application-identity's bucket_arns."
}

output "retention_mode" {
  value       = artesca_bucket_object_lock.this.retention_mode
  description = "Default retention mode."
}

output "retention_period" {
  value       = var.retention_days != null ? "${var.retention_days} days" : "${var.retention_years} years"
  description = "Default retention period."
}
