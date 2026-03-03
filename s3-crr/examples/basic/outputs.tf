output "crr_summary" {
  description = "Complete summary of the CRR configuration"
  value       = module.s3_crr.summary
}

output "source_bucket_name" {
  description = "Name of the source bucket"
  value       = module.s3_crr.source_bucket_name
}

output "destination_bucket_name" {
  description = "Name of the destination bucket"
  value       = module.s3_crr.destination_bucket_name
}

output "source_role_arn" {
  description = "ARN of the source IAM role"
  value       = module.s3_crr.source_role_arn
}

output "destination_role_arn" {
  description = "ARN of the destination IAM role"
  value       = module.s3_crr.destination_role_arn
}

output "replication_status" {
  description = "Status of the replication configuration"
  value       = module.s3_crr.replication_status
}
