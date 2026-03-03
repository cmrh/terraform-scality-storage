output "bucket_name" {
  description = "Name of the bucket with lifecycle configuration"
  value       = var.bucket_name
}

output "lifecycle_rules" {
  description = "Configured lifecycle rules"
  value       = var.lifecycle_rules
}

output "lifecycle_configuration_id" {
  description = "ID of the lifecycle configuration resource"
  value       = aws_s3_bucket_lifecycle_configuration.this.id
}

output "rule_count" {
  description = "Number of lifecycle rules configured"
  value       = length(var.lifecycle_rules)
}

output "enabled_rules" {
  description = "List of enabled rule IDs"
  value       = [for rule in var.lifecycle_rules : rule.id if rule.enabled]
}
