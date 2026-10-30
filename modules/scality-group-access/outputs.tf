output "group_name" {
  description = "Group name."
  value       = scality_group.this.group_name
}

output "group_id" {
  description = "Unique group identifier."
  value       = scality_group.this.group_id
}

output "group_arn" {
  description = "Group ARN."
  value       = scality_group.this.arn
}

output "policy_arns" {
  description = "ARNs of every policy attached to the group, created here or passed in policy_arns."
  value = concat(
    [for a in scality_iam_group_policy_attachment.created : a.policy_arn],
    [for a in scality_iam_group_policy_attachment.existing : a.policy_arn],
  )
}
