output "bucket_name" {
  value       = module.bucket.bucket_name
  description = "Bucket name."
}

output "bucket_arn" {
  value       = module.bucket.bucket_arn
  description = "Bucket ARN, e.g. for artesca-application-identity's bucket_arns."
}

output "transition_rule_id" {
  value       = artesca_bucket_workflow_transition.this.rule_id
  description = "Transition rule ID (the workflow ID in the ARTESCA UI)."
}
