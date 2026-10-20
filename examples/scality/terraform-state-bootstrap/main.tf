# Terraform state bootstrap example.
#
# Creates a dedicated account (with Console login) and a versioned, encrypted
# bucket for Terraform/OpenTofu state.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
  }
}

# Reads SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY and
# SCALITY_CONSOLE_ENDPOINT, SCALITY_CONSOLE_USERNAME, SCALITY_CONSOLE_PASSWORD
# from the environment.
provider "scality" {}

variable "account_name" {
  type        = string
  default     = "terraform-state"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

module "state" {
  source = "../../../modules/scality/terraform-state-bootstrap"

  account_name  = var.account_name
  account_email = "${var.account_name}@state.example.com"
  bucket_name   = "${var.account_name}-tfstate"
}

output "bucket_name" {
  value = module.state.bucket_name
}

output "access_key" {
  value     = module.state.access_key
  sensitive = true
}

output "secret_key" {
  value     = module.state.secret_key
  sensitive = true
}
