output "username" {
  description = "Username."
  value       = artesca_user.this.username
}

output "user_id" {
  description = "Unique user identifier."
  value       = artesca_user.this.user_id
}

output "user_arn" {
  description = "User ARN, for bucket policies that name this user."
  value       = artesca_user.this.arn
}

output "access_key" {
  description = "S3 access key for the application."
  value       = artesca_user_access_key.this.access_key_id
  sensitive   = true

  # Consumers of the key wait for the policy, and are destroyed before it.
  depends_on = [artesca_user_policy.this]
}

output "secret_key" {
  description = "S3 secret key paired with access_key."
  value       = artesca_user_access_key.this.secret_access_key
  sensitive   = true

  depends_on = [artesca_user_policy.this]
}

output "policy_name" {
  description = "Name of the inline policy."
  value       = artesca_user_policy.this.policy_name
}

output "effective_policy" {
  description = "Policy applied to the user (preset or custom)."
  value       = local.effective_policy
}
