# ARTESCA tiered bucket example: objects move to a RING bucket after N days.
#
# RING:    account -> operator -> versioned bucket + tiering key (ring-replication-target)
# ARTESCA: RING location -> account -> tiered bucket -> app user

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
    artesca = {
      source  = "cmrh/artesca"
      version = "~> 1.1"
    }
  }
}

# Reads SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY.
provider "scality" {}

# Reads ARTESCA_MANAGEMENT_ENDPOINT, ARTESCA_OIDC_URL, ARTESCA_USERNAME,
# ARTESCA_PASSWORD, ARTESCA_S3_ENDPOINT.
provider "artesca" {}

variable "name" {
  type        = string
  default     = "tiered-01"
  description = "Base name for the accounts, buckets and location. Override (TF_VAR_name) to avoid collisions."
}

variable "ring_endpoint" {
  type        = string
  description = "RING S3 endpoint, as ARTESCA reaches it."
}

variable "transition_days" {
  type        = number
  default     = 30
  description = "Days after creation when objects move to RING."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Set true and apply before destroying, so the ARTESCA bucket's objects are deleted with it."
}

module "ring_account" {
  source = "../../modules/scality-account-management"

  account_name  = "${var.name}-ring"
  account_email = "${var.name}-ring@example.com"
  console_login = false
}

module "ring_operator" {
  source = "../../modules/scality-account-operator"

  account_access_key = module.ring_account.access_key
  account_secret_key = module.ring_account.secret_key
}

module "ring_bucket" {
  source = "../../modules/scality-ring-replication-target"

  account_access_key = module.ring_operator.access_key
  account_secret_key = module.ring_operator.secret_key
  bucket_name        = "${var.name}-cold"
  purpose            = "tiering"
}

module "location" {
  source = "../../modules/artesca-storage-location"

  name        = "${var.name}-cold"
  endpoint    = var.ring_endpoint
  bucket_name = module.ring_bucket.bucket_name
  access_key  = module.ring_bucket.access_key
  secret_key  = module.ring_bucket.secret_key
}

module "account" {
  source = "../../modules/artesca-account-management"

  account_name  = var.name
  account_email = "${var.name}@example.com"
}

module "bucket" {
  source = "../../modules/artesca-tiered-bucket"

  account_name        = module.account.account_name
  bucket_name         = "${var.name}-data"
  transition_location = module.location.name
  transition_days     = var.transition_days
  force_destroy       = var.force_destroy
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

output "ring_bucket" {
  value = module.ring_bucket.bucket_name
}

output "app_access_key" {
  value     = module.app.access_key
  sensitive = true
}

output "app_secret_key" {
  value     = module.app.secret_key
  sensitive = true
}

output "ring_operator_access_key" {
  value     = module.ring_operator.access_key
  sensitive = true
}

output "ring_operator_secret_key" {
  value     = module.ring_operator.secret_key
  sensitive = true
}
