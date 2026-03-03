terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Configure AWS provider to use Scality S3 endpoint
provider "aws" {
  region = "us-east-1"

  # Use custom endpoint for Scality
  endpoints {
    iam = var.scality_endpoint
    s3  = var.scality_endpoint
    sts = var.scality_endpoint
  }

  # Credentials from environment variables or passed explicitly
  access_key = var.access_key != null ? var.access_key : null
  secret_key = var.secret_key != null ? var.secret_key : null

  # Skip AWS-specific validations
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  # Allow HTTP for local/development deployments
  insecure = var.use_https ? false : true
}

# IAM Users Module
module "users" {
  source = "./users"

  users = var.users
}

# IAM Groups Module
module "groups" {
  source = "./groups"

  groups = var.groups
}

# IAM Policies Module
module "policies" {
  source = "./policies"

  policies = var.policies
}

# Attach users to groups
resource "aws_iam_user_group_membership" "user_groups" {
  for_each = {
    for membership in local.user_group_memberships : "${membership.user}_${membership.group}" => membership
  }

  user   = each.value.user
  groups = [each.value.group]

  depends_on = [
    module.users,
    module.groups
  ]
}

# Attach policies to users
resource "aws_iam_user_policy_attachment" "user_policies" {
  for_each = {
    for attachment in local.user_policy_attachments : "${attachment.user}_${attachment.policy}" => attachment
  }

  user       = each.value.user
  policy_arn = module.policies.policy_arns[each.value.policy]

  depends_on = [
    module.users,
    module.policies
  ]
}

# Attach policies to groups
resource "aws_iam_group_policy_attachment" "group_policies" {
  for_each = {
    for attachment in local.group_policy_attachments : "${attachment.group}_${attachment.policy}" => attachment
  }

  group      = each.value.group
  policy_arn = module.policies.policy_arns[each.value.policy]

  depends_on = [
    module.groups,
    module.policies
  ]
}

# Local values for processing relationships
locals {
  # Flatten user-to-group memberships
  user_group_memberships = flatten([
    for user_name, user in var.users : [
      for group in coalesce(user.groups, []) : {
        user  = user_name
        group = group
      }
    ]
  ])

  # Flatten user-to-policy attachments
  user_policy_attachments = flatten([
    for user_name, user in var.users : [
      for policy in coalesce(user.policies, []) : {
        user   = user_name
        policy = policy
      }
    ]
  ])

  # Flatten group-to-policy attachments
  group_policy_attachments = flatten([
    for group_name, group in var.groups : [
      for policy in coalesce(group.policies, []) : {
        group  = group_name
        policy = policy
      }
    ]
  ])
}
