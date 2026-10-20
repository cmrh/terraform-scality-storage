output "account_name" {
  description = "Account name on the cluster."
  value       = var.account_name
}

output "account_id" {
  description = "Cluster-assigned account ID."
  value       = module.account.account_id
}

output "operator_access_key" {
  description = "Operator user's access key."
  value       = module.operator.access_key
  sensitive   = true
}

output "operator_secret_key" {
  description = "Operator user's secret key."
  value       = module.operator.secret_key
  sensitive   = true
}

output "bucket_name" {
  description = "Bucket created by the operator."
  value       = module.bucket.bucket_name
}

output "app_username" {
  description = "Application user (read-write on the bucket)."
  value       = module.app_user.username
}

output "app_access_key" {
  description = "Application user's access key."
  value       = module.app_user.access_key
  sensitive   = true
}

output "app_secret_key" {
  description = "Application user's secret key."
  value       = module.app_user.secret_key
  sensitive   = true
}
