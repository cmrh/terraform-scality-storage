output "source_bucket_arn" {
  description = "Source bucket ARN."
  value       = local.source_bucket_arn
}

output "dest_bucket_arn" {
  description = "Destination bucket ARN."
  value       = local.dest_bucket_arn
}

output "source_role_arn" {
  description = "ARN of the source-cluster IAM role assumed by backbeat to perform replication."
  value       = scality_iam_role.source.arn
}

output "dest_role_arn" {
  description = "ARN of the destination-cluster IAM role assumed by backbeat to perform replication."
  value       = scality_iam_role.dest.arn
}

output "bidirectional" {
  description = "Whether reverse replication (dest → source) is also configured."
  value       = var.bidirectional
}
