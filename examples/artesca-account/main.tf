# ARTESCA account example.

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
# ARTESCA_PASSWORD from the environment.
provider "artesca" {}

variable "account_name" {
  type        = string
  default     = "artesca-account-01"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

module "account" {
  source = "../../modules/artesca-account-management"

  account_name  = var.account_name
  account_email = "${var.account_name}@example.com"
}

output "account_id" {
  value = module.account.account_id
}

output "access_key" {
  value     = module.account.access_key
  sensitive = true
}

output "secret_key" {
  value     = module.account.secret_key
  sensitive = true
}
