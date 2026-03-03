output "users" {
  description = "Map of created IAM users"
  value = {
    for name, user in aws_iam_user.users : name => {
      name = user.name
      arn  = user.arn
      path = user.path
      tags = user.tags
    }
  }
}

output "access_keys" {
  description = "Map of user access keys"
  value = {
    for name, key in aws_iam_access_key.user_keys : name => {
      access_key = key.id
      secret_key = key.secret
      status     = key.status
    }
  }
  sensitive = true
}

output "user_arns" {
  description = "Map of user names to ARNs"
  value = {
    for name, user in aws_iam_user.users : name => user.arn
  }
}
