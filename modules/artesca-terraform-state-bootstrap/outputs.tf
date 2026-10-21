output "bucket_name" {
  value       = module.bucket.bucket_name
  description = "State bucket name, for the backend's bucket."
}

output "account_name" {
  value       = module.account.account_name
  description = "Account name."
}

output "account_id" {
  value       = module.account.account_id
  description = "Account ID."
}

output "access_key" {
  value       = module.state_user.access_key
  sensitive   = true
  description = "State user's access key, for the backend."
}

output "secret_key" {
  value       = module.state_user.secret_key
  sensitive   = true
  description = "State user's secret key."
}
