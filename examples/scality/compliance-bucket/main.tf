# Compliance bucket example.
#
# account -> operator -> bucket with Object Lock, a default retention rule,
# encryption and a lifecycle rule.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
  }
}

# Reads SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY from the environment.
provider "scality" {}

variable "account_name" {
  type        = string
  default     = "compliance-01"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

module "account" {
  source = "../../../modules/scality/scality-account-management"

  account_name  = var.account_name
  account_email = "${var.account_name}@compliance.example.com"
  console_login = false
}

module "operator" {
  source = "../../../modules/scality/account-operator"

  account_access_key = module.account.access_key
  account_secret_key = module.account.secret_key
}

module "bucket" {
  source = "../../../modules/scality/compliance-bucket"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  bucket_name        = "${var.account_name}-records"

  retention_mode = "GOVERNANCE"
  retention_days = 1
}

output "bucket_name" {
  value = module.bucket.bucket_name
}

output "retention_period" {
  value = module.bucket.retention_period
}
