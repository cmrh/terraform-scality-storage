output "username" {
  description = "Operator user's username."
  value       = module.user.username
}

output "user_arn" {
  description = "Operator user's ARN."
  value       = module.user.user_arn
}

output "access_key" {
  description = "Operator's S3 access key. Pass this as account_access_key to downstream wrapper modules (application-identity, application-bucket, etc.) instead of the account-root credentials."
  value       = module.user.access_key
  sensitive   = true
}

output "secret_key" {
  description = "Operator's S3 secret key paired with access_key."
  value       = module.user.secret_key
  sensitive   = true
}
