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
  depends_on = [artesca_user_policy.this, artesca_user_policy.policies, artesca_user_policy_attachment.this]
}

output "secret_key" {
  description = "S3 secret key paired with access_key."
  value       = artesca_user_access_key.this.secret_access_key
  sensitive   = true

  depends_on = [artesca_user_policy.this, artesca_user_policy.policies, artesca_user_policy_attachment.this]
}

output "policy_name" {
  description = "Name of the preset or policy_document policy; null when there is none."
  value       = one(artesca_user_policy.this[*].policy_name)
}

output "policy_names" {
  description = "Names of every inline policy: the preset or policy_document policy, then policies."
  value       = concat(artesca_user_policy.this[*].policy_name, [for p in artesca_user_policy.policies : p.policy_name])
}

output "policy_arns" {
  description = "ARNs of the managed policies attached to the user."
  value       = [for a in artesca_user_policy_attachment.this : a.policy_arn]
}

output "effective_policy" {
  description = "The preset or policy_document policy; null when there is none."
  value       = local.effective_policy
}
