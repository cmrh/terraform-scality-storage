# Group access example.
#
# account -> operator -> two application users, each with read-write on its
# own bucket; a group gives both read-only access to a shared archive bucket.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6" # TODO(#67): raise to the release with scality_iam_group_policy_attachment
    }
  }
}

# Reads SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY from the environment.
provider "scality" {}

variable "account_name" {
  type        = string
  default     = "group-access-01"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

locals {
  apps = toset(["ingest", "reporting"])
}

module "account" {
  source = "../../modules/scality-account-management"

  account_name  = var.account_name
  account_email = "${var.account_name}@group-access.example.com"
  console_login = false
}

module "operator" {
  source = "../../modules/scality-account-operator"

  account_access_key = module.account.access_key
  account_secret_key = module.account.secret_key
}

module "app_bucket" {
  source   = "../../modules/scality-application-bucket"
  for_each = local.apps

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  bucket_name        = "${var.account_name}-${each.key}"
}

module "archive" {
  source = "../../modules/scality-application-bucket"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  bucket_name        = "${var.account_name}-archive"
}

module "app" {
  source   = "../../modules/scality-application-identity"
  for_each = local.apps

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  username           = "${var.account_name}-${each.key}"
  bucket_arns        = [module.app_bucket[each.key].bucket_arn]
}

module "archive_readers" {
  source = "../../modules/scality-group-access"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  group_name         = "archive-readers"

  policies = {
    archive-read = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:GetObjectVersion"]
          Resource = "${module.archive.bucket_arn}/*"
        },
        {
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
          Resource = module.archive.bucket_arn
        },
      ]
    })
  }

  members = [for m in module.app : m.username]
}

output "archive_readers" {
  value = module.archive_readers.group_name
}

output "app_access_keys" {
  value     = { for k, m in module.app : k => m.access_key }
  sensitive = true
}

output "app_secret_keys" {
  value     = { for k, m in module.app : k => m.secret_key }
  sensitive = true
}
