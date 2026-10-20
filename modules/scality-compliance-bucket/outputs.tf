output "bucket_name" {
  description = "Bucket name."
  value       = scality_bucket.this.bucket
}

output "bucket_arn" {
  description = "Bucket ARN (\"arn:aws:s3:::<bucket_name>\"). Pass to application-identity.bucket_arns to grant a workload user access."
  value       = "arn:aws:s3:::${scality_bucket.this.bucket}"
}

output "retention_mode" {
  description = "Configured retention mode (GOVERNANCE or COMPLIANCE)."
  value       = var.retention_mode
}

output "retention_period" {
  description = "Default retention period applied to new objects."
  value = (
    var.retention_days != null
    ? "${var.retention_days} days"
    : "${var.retention_years} years"
  )
}

output "object_lock_enabled" {
  description = "Always true for this module."
  value       = true
}
