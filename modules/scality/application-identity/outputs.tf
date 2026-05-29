output "username" {
  description = "Created user's username."
  value       = scality_user.this.username
}

output "user_id" {
  description = "Unique user identifier."
  value       = scality_user.this.user_id
}

output "user_arn" {
  description = "User ARN (use in bucket policies that reference this principal)."
  value       = scality_user.this.arn
}

output "user_path" {
  description = "IAM path of the user."
  value       = scality_user.this.path
}

output "access_key" {
  description = "S3 access key for the application user. Configure the application's AWS_ACCESS_KEY_ID with this value."
  value       = scality_user_access_key.this.access_key_id
  sensitive   = true

  # Ensure the inline policy is attached before downstream consumers
  # use this key, and equivalently, that downstream consumers are torn
  # down before the policy is removed during destroy. Without this,
  # Terraform may destroy the policy in parallel with dependents,
  # leaving the user without permissions mid-destroy and failing
  # subsequent IAM calls.
  depends_on = [scality_user_policy.this]
}

output "secret_key" {
  description = "S3 secret key paired with access_key. Configure the application's AWS_SECRET_ACCESS_KEY with this value."
  value       = scality_user_access_key.this.secret_access_key
  sensitive   = true

  depends_on = [scality_user_policy.this]
}

output "policy_name" {
  description = "Name of the inline policy attached to the user."
  value       = scality_user_policy.this.policy_name
}

output "effective_policy" {
  description = "Rendered JSON policy applied to the user. Useful for debugging or auditing what was actually granted (preset or custom document)."
  value       = local.effective_policy
}
