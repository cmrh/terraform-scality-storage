output "role_name" {
  description = "Name of the IAM role."
  value       = scality_iam_role.this.role_name
}

output "role_arn" {
  description = "ARN of the IAM role. Use as role_arn in the management side's provider assume_role block."
  value       = scality_iam_role.this.arn

  # The role is only usable once its permissions are attached.
  depends_on = [scality_iam_role_policy_attachment.this]
}

output "policy_arn" {
  description = "ARN of the managed permissions policy attached to the role."
  value       = scality_iam_policy.this.arn
}

output "effective_policy" {
  description = "Rendered JSON permissions policy applied to the role (default or custom). Useful for auditing what the management account can do in this sub-account."
  value       = local.effective_policy
}
