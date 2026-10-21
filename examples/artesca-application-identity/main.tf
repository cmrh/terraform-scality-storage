# ARTESCA application identity example.
#
# account -> bucket -> app user with read-write access to that bucket only.

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
  default     = "artesca-identity-01"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

module "account" {
  source = "../../modules/artesca-account-management"

  account_name  = var.account_name
  account_email = "${var.account_name}@example.com"
}

resource "artesca_bucket" "data" {
  account_name       = module.account.account_name
  name               = "${var.account_name}-data"
  versioning_enabled = true
}

module "app" {
  source = "../../modules/artesca-application-identity"

  account_name   = module.account.account_name
  username       = "app"
  access_pattern = "read-write"
  bucket_arns    = ["arn:aws:s3:::${artesca_bucket.data.name}"]
}

output "bucket" {
  value = artesca_bucket.data.name
}

output "app_access_key" {
  value     = module.app.access_key
  sensitive = true
}

output "app_secret_key" {
  value     = module.app.secret_key
  sensitive = true
}
