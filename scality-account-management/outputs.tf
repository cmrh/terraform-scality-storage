output "users" {
  description = "Map of created IAM users with their details"
  value       = module.users.users
}

output "user_access_keys" {
  description = "Map of user access keys (sensitive)"
  value       = module.users.access_keys
  sensitive   = true
}

output "groups" {
  description = "Map of created IAM groups"
  value       = module.groups.groups
}

output "policies" {
  description = "Map of created IAM policies"
  value       = module.policies.policies
}

output "policy_arns" {
  description = "Map of policy names to ARNs"
  value       = module.policies.policy_arns
}

output "user_group_memberships" {
  description = "List of user-to-group memberships"
  value = [
    for membership in aws_iam_user_group_membership.user_groups : {
      user   = membership.user
      groups = membership.groups
    }
  ]
}

output "summary" {
  description = "Summary of created resources"
  value = {
    users_created    = length(module.users.users)
    groups_created   = length(module.groups.groups)
    policies_created = length(module.policies.policies)
    user_names       = keys(module.users.users)
    group_names      = keys(module.groups.groups)
    policy_names     = keys(module.policies.policies)
  }
}
