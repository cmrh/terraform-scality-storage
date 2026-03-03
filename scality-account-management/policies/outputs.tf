output "policies" {
  description = "Map of created IAM policies"
  value = {
    for name, policy in aws_iam_policy.policies : name => {
      name = policy.name
      arn  = policy.arn
      path = policy.path
    }
  }
}

output "policy_arns" {
  description = "Map of policy names to ARNs"
  value = {
    for name, policy in aws_iam_policy.policies : name => policy.arn
  }
}
