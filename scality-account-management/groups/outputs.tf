output "groups" {
  description = "Map of created IAM groups"
  value = {
    for name, group in aws_iam_group.groups : name => {
      name = group.name
      arn  = group.arn
      path = group.path
    }
  }
}

output "group_arns" {
  description = "Map of group names to ARNs"
  value = {
    for name, group in aws_iam_group.groups : name => group.arn
  }
}
