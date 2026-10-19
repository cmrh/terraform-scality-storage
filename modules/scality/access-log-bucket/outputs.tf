output "bucket_name" {
  description = "Log bucket name."
  value       = scality_bucket.this.bucket
}

output "bucket_arn" {
  description = "Log bucket ARN (\"arn:aws:s3:::<bucket_name>\"). Pass to application-identity.bucket_arns to grant read access to the logs."
  value       = "arn:aws:s3:::${scality_bucket.this.bucket}"
}

output "logged_buckets" {
  description = "Source buckets with logging enabled, as bucket name => key prefix."
  value       = { for k, v in scality_bucket_logging.this : k => v.target_prefix }
}

output "retention_days" {
  description = "Days after which log objects are deleted."
  value       = var.retention_days
}

output "policy" {
  description = "Bucket policy applied to the log bucket."
  value       = local.policy
}
