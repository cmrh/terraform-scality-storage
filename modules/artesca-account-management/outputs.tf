output "account_name" {
  value       = artesca_account.this.name
  description = "Account name. Account-scoped artesca resources take it as account_name."
}

output "account_id" {
  value       = artesca_account.this.id
  description = "Account ID."
}

output "account_arn" {
  value       = artesca_account.this.arn
  description = "Account root ARN."
}

output "canonical_id" {
  value       = artesca_account.this.canonical_id
  description = "Canonical ID of the account."
}

output "access_key" {
  value       = artesca_account.this.access_key
  sensitive   = true
  description = "Account S3 access key, generated at creation."
}

output "secret_key" {
  value       = artesca_account.this.secret_key
  sensitive   = true
  description = "Account S3 secret key, generated at creation."
}
