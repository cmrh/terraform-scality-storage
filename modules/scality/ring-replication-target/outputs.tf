output "bucket_name" {
  value       = scality_bucket.this.bucket
  description = "Target bucket name."
}

output "bucket_arn" {
  value       = local.bucket_arn
  description = "Target bucket ARN."
}

output "access_key" {
  value       = module.replication_user.access_key
  description = "Replication user's access key, for ARTESCA's RING location."
}

output "secret_key" {
  value       = module.replication_user.secret_key
  sensitive   = true
  description = "Replication user's secret key."
}
