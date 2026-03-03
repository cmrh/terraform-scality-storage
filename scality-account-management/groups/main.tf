terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Create IAM groups
resource "aws_iam_group" "groups" {
  for_each = var.groups

  name = each.key
  path = each.value.path
}
