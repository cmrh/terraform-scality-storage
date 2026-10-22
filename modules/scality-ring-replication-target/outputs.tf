output "bucket_name" {
  value       = scality_bucket.this.bucket
  description = "Target bucket name."
}

output "bucket_arn" {
  value       = local.bucket_arn
  description = "Target bucket ARN."
}

output "role_arn" {
  value       = try(scality_iam_role.crr[0].arn, null)
  description = "Destination role ARN for purpose = \"crr\", or null."
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
