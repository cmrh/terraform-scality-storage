# ARTESCA Terraform state bootstrap example.

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
  default     = "terraform-state"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

module "state" {
  source = "../../modules/artesca-terraform-state-bootstrap"

  account_name  = var.account_name
  account_email = "${var.account_name}@example.com"
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
