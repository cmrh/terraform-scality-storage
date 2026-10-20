# Access logging example.
#
# account -> operator -> app bucket + log bucket; the app bucket's access
# logs are delivered to the log bucket under "<app bucket>/".

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
  default     = "access-logging-01"
  description = "Account name to create. Override (TF_VAR_account_name) to avoid collisions."
}

module "account" {
  source = "../../modules/scality-account-management"

  account_name  = var.account_name
  account_email = "${var.account_name}@access-logging.example.com"
  console_login = false
}

module "operator" {
  source = "../../modules/scality-account-operator"

  account_access_key = module.account.access_key
  account_secret_key = module.account.secret_key
}

module "app_bucket" {
  source = "../../modules/scality-application-bucket"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  bucket_name        = "${var.account_name}-data"
}

module "access_logs" {
  source = "../../modules/scality-access-log-bucket"

  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key

  bucket_name = "${var.account_name}-logs"

  logged_buckets = {
    (module.app_bucket.bucket_name) = "${module.app_bucket.bucket_name}/"
  }
}

output "app_bucket" {
  value = module.app_bucket.bucket_name
}

output "log_bucket" {
  value = module.access_logs.bucket_name
}

output "operator_access_key" {
  value     = module.operator.access_key
  sensitive = true
}

output "operator_secret_key" {
  value     = module.operator.secret_key
  sensitive = true
}
