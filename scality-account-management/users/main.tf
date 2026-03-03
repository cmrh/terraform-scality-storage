terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Create IAM users
resource "aws_iam_user" "users" {
  for_each = var.users

  name = each.key
  path = each.value.path
  tags = each.value.tags
}

# Generate access keys for users
resource "aws_iam_access_key" "user_keys" {
  for_each = {
    for user_name, user in var.users : user_name => user
    if user.generate_access_key
  }

  user = aws_iam_user.users[each.key].name

  depends_on = [aws_iam_user.users]
}
