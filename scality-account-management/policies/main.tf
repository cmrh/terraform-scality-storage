terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Create IAM policies
resource "aws_iam_policy" "policies" {
  for_each = var.policies

  name        = each.key
  description = each.value.description
  policy      = each.value.policy_document
  path        = each.value.path
}
