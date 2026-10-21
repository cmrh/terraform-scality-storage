output "bucket_name" {
  value       = artesca_bucket.this.name
  description = "Bucket name."
}

output "bucket_arn" {
  value       = "arn:aws:s3:::${artesca_bucket.this.name}"
  description = "Bucket ARN, e.g. for artesca-application-identity's bucket_arns."
}

output "versioning" {
  value       = artesca_bucket.this.versioning_enabled
  description = "Whether versioning is enabled."
}

output "expiration_rule_id" {
  value       = try(artesca_bucket_workflow_expiration.this[0].rule_id, null)
  description = "Expiration rule ID (the workflow ID in the ARTESCA UI), or null."
}
