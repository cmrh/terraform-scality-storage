output "account_name" {
  description = "Name of the created account."
  value       = var.console_login ? scality_console_account.this[0].account_name : scality_account.this[0].name
}

output "account_id" {
  description = "Account identifier."
  value       = var.console_login ? scality_console_account.this[0].id : scality_account.this[0].id
}

output "created_at" {
  description = "Account creation timestamp (ISO 8601)."
  value       = var.console_login ? scality_console_account.this[0].created_at : scality_account.this[0].create_date
}

output "account_arn" {
  description = "Account ARN. Available only when console_login = false; null otherwise (scality_console_account does not return an ARN)."
  value       = var.console_login ? null : scality_account.this[0].arn
}

output "canonical_id" {
  description = "Canonical ID, used in S3 bucket policies. Available only when console_login = false; null otherwise."
  value       = var.console_login ? null : scality_account.this[0].canonical_id
}

output "access_key" {
  description = "Stable S3 access key. When console_login = true, this is the layered scality_account_access_key (UI-independent). When false, this is the scality_account-generated bootstrap key (already Terraform-owned)."
  value       = var.console_login ? scality_account_access_key.stable[0].access_key : scality_account.this[0].access_key
  sensitive   = true
}

output "secret_key" {
  description = "Stable S3 secret key paired with access_key."
  value       = var.console_login ? scality_account_access_key.stable[0].secret_key : scality_account.this[0].secret_key
  sensitive   = true
}

output "console_password" {
  description = "Auto-generated password for Console (UI) login. Available only when console_login = true; null otherwise. The user should change this in the Console UI after first login — the module's stored value will then be stale (Read does not query the API for the password)."
  value       = var.console_login ? scality_console_account.this[0].password : null
  sensitive   = true
}
