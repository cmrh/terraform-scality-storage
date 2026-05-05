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

output "source_crr_operator_username" {
  description = "Username of the CRR operator on the source cluster. Provided for reference; the operator is internal to CRR mechanics — its credentials are not surfaced. Use the application-identity module to grant application or verification access to the bucket."
  value       = scality_user.source_crr_operator.username
}

output "dest_crr_operator_username" {
  description = "Username of the CRR operator on the destination cluster. Provided for reference; the operator is internal to CRR mechanics — its credentials are not surfaced. Use the application-identity module to grant application or verification access to the bucket."
  value       = scality_user.dest_crr_operator.username
}
