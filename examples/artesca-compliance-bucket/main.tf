# ARTESCA compliance bucket example.
#
# account -> bucket with object lock and a 1-day GOVERNANCE default retention
# -> app user with read-write access to it.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    artesca = {
      source  = "cmrh/artesca"
      version = "~> 1.2"
    }
  }
}

# Reads ARTESCA_MANAGEMENT_ENDPOINT, ARTESCA_OIDC_URL, ARTESCA_USERNAME,
# ARTESCA_PASSWORD, ARTESCA_S3_ENDPOINT from the environment.
provider "artesca" {}

variable "account_name" {
  type        = string
  default     = "artesca-compliance-01"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Set true and apply before destroying, so GOVERNANCE-locked versions are deleted with the bucket."
}

module "account" {
  source = "../../modules/artesca-account-management"

  account_name  = var.account_name
  account_email = "${var.account_name}@example.com"
}

module "bucket" {
  source = "../../modules/artesca-compliance-bucket"

  account_name   = module.account.account_name
  bucket_name    = "${var.account_name}-records"
  retention_mode = "GOVERNANCE"
  retention_days = 1
  force_destroy  = var.force_destroy
}

module "app" {
  source = "../../modules/artesca-application-identity"

  account_name = module.account.account_name
  username     = "app"
  bucket_arns  = [module.bucket.bucket_arn]
}

output "bucket" {
  value = module.bucket.bucket_name
}

output "account_access_key" {
  value     = module.account.access_key
  sensitive = true
}

output "account_secret_key" {
  value     = module.account.secret_key
  sensitive = true
}

output "app_access_key" {
  value     = module.app.access_key
  sensitive = true
}

output "app_secret_key" {
  value     = module.app.secret_key
  sensitive = true
}
