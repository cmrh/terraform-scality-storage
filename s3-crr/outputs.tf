# Source outputs
output "source_bucket_name" {
  description = "Name of the source bucket"
  value       = var.source_bucket_name
}

output "source_bucket_arn" {
  description = "ARN of the source bucket"
  value       = "arn:aws:s3:::${var.source_bucket_name}"
}

output "source_account_id" {
  description = "Source account ID"
  value       = local.source_account_id
}

output "source_policy_arn" {
  description = "ARN of the source IAM policy"
  value       = aws_iam_policy.source_crr.arn
}

output "source_role_arn" {
  description = "ARN of the source IAM role"
  value       = aws_iam_role.source_crr.arn
}

output "source_role_name" {
  description = "Name of the source IAM role"
  value       = aws_iam_role.source_crr.name
}

# Destination outputs
output "destination_bucket_name" {
  description = "Name of the destination bucket"
  value       = var.destination_bucket_name
}

output "destination_bucket_arn" {
  description = "ARN of the destination bucket"
  value       = "arn:aws:s3:::${var.destination_bucket_name}"
}

output "destination_account_id" {
  description = "Destination account ID"
  value       = local.destination_account_id
}

output "destination_policy_arn" {
  description = "ARN of the destination IAM policy"
  value       = aws_iam_policy.destination_crr.arn
}

output "destination_role_arn" {
  description = "ARN of the destination IAM role"
  value       = aws_iam_role.destination_crr.arn
}

output "destination_role_name" {
  description = "Name of the destination IAM role"
  value       = aws_iam_role.destination_crr.name
}

# Replication outputs
output "replication_configuration_id" {
  description = "ID of the replication configuration"
  value       = aws_s3_bucket_replication_configuration.source.id
}

output "replication_status" {
  description = "Status of the replication rule"
  value       = var.replication_status
}

# Summary outputs
output "summary" {
  description = "Summary of the CRR configuration"
  value = {
    source = {
      bucket     = var.source_bucket_name
      account_id = local.source_account_id
      role_arn   = aws_iam_role.source_crr.arn
      policy_arn = aws_iam_policy.source_crr.arn
    }
    destination = {
      bucket     = var.destination_bucket_name
      account_id = local.destination_account_id
      role_arn   = aws_iam_role.destination_crr.arn
      policy_arn = aws_iam_policy.destination_crr.arn
    }
    replication = {
      status = var.replication_status
      prefix = var.replication_prefix
    }
  }
}
