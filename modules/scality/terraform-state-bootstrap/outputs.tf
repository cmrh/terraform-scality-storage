output "bucket_name" {
  description = "Name of the state bucket."
  value       = scality_bucket.state.bucket
}

output "account_name" {
  description = "Dedicated state account name."
  value       = scality_account.state.name
}

output "account_id" {
  description = "Scality account ID."
  value       = scality_account.state.id
}

output "access_key" {
  description = "Stable access key for the state account. Use as AWS_ACCESS_KEY_ID in downstream consumers' backend configuration."
  value       = scality_account_access_key.state.access_key
  sensitive   = true
}

output "secret_key" {
  description = "Stable secret key for the state account. Use as AWS_SECRET_ACCESS_KEY in downstream consumers' backend configuration."
  value       = scality_account_access_key.state.secret_key
  sensitive   = true
}
