output "bucket_name" {
  description = "Bucket name."
  value       = scality_bucket.this.bucket
}

output "bucket_arn" {
  description = "Bucket ARN (\"arn:aws:s3:::<bucket_name>\"). Pass directly to application-identity.bucket_arns to grant a workload user access."
  value       = "arn:aws:s3:::${scality_bucket.this.bucket}"
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on the bucket."
  value       = var.versioning
}

output "lifecycle_rules" {
  description = "Lifecycle rules applied to the bucket. Useful for auditing the active hygiene rules."
  value       = local.rule_specs
}
