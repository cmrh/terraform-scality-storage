# ARTESCA group access example.
#
# account -> two application users, each with read-write on its own bucket;
# a group gives both read-only access to a shared archive bucket.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    artesca = {
      source  = "cmrh/artesca"
      version = "~> 1.1"
    }
  }
}

# Reads ARTESCA_MANAGEMENT_ENDPOINT, ARTESCA_OIDC_URL, ARTESCA_USERNAME,
# ARTESCA_PASSWORD, ARTESCA_S3_ENDPOINT from the environment.
provider "artesca" {}

variable "account_name" {
  type        = string
  default     = "artesca-group-01"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

locals {
  apps = toset(["ingest", "reporting"])
}

module "account" {
  source = "../../modules/artesca-account-management"

  account_name  = var.account_name
  account_email = "${var.account_name}@example.com"
}

module "app_bucket" {
  source   = "../../modules/artesca-application-bucket"
  for_each = local.apps

  account_name = module.account.account_name
  bucket_name  = "${var.account_name}-${each.key}"
}

module "archive" {
  source = "../../modules/artesca-application-bucket"

  account_name = module.account.account_name
  bucket_name  = "${var.account_name}-archive"
}

module "app" {
  source   = "../../modules/artesca-application-identity"
  for_each = local.apps

  account_name = module.account.account_name
  username     = each.key
  bucket_arns  = [module.app_bucket[each.key].bucket_arn]
}

module "archive_readers" {
  source = "../../modules/artesca-group-access"

  account_name = module.account.account_name
  group_name   = "archive-readers"

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
