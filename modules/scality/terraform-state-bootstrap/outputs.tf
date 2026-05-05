output "bucket_name" {
  description = "Name of the state bucket."
  value       = scality_bucket.state.bucket
}

output "account_name" {
  description = "Dedicated state account name."
  value       = var.console_login ? scality_console_account.state[0].account_name : scality_account.state[0].name
}

output "account_id" {
  description = "Scality account ID."
  value       = var.console_login ? scality_console_account.state[0].id : scality_account.state[0].id
}

output "access_key" {
  description = "Stable access key for the state account. Use as AWS_ACCESS_KEY_ID in downstream consumers' backend configuration. When console_login = true, this is the layered scality_account_access_key (UI-independent); when false, this is the scality_account-generated key."
  value       = local.ak
  sensitive   = true
}

output "secret_key" {
  description = "Stable secret key paired with access_key. Use as AWS_SECRET_ACCESS_KEY in downstream consumers' backend configuration."
  value       = local.sk
  sensitive   = true
}

output "console_password" {
  description = "Auto-generated Console (UI) password for the state account. Set only when console_login = true; null otherwise. Treat as a one-time bootstrap value: the admin should change it in the Console UI after first login, after which the value here is stale."
  value       = var.console_login ? scality_console_account.state[0].password : null
  sensitive   = true
}
