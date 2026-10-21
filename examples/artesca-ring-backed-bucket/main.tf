# ARTESCA bucket stored on RING.
#
# RING:    account -> operator -> versioned bucket + key (ring-replication-target,
#          purpose = "tiering": ARTESCA writes, reads and deletes objects there)
# ARTESCA: RING location -> account -> bucket on that location -> app user

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
  default     = "ring-backed-01"
  description = "Base name for the accounts, buckets and location. Override (TF_VAR_name) to avoid collisions."
}

variable "ring_endpoint" {
  type        = string
  description = "RING S3 endpoint, as ARTESCA reaches it."
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
  bucket_name        = "${var.name}-store"
  purpose            = "tiering"
}

module "location" {
  source = "../../modules/artesca-storage-location"

  name        = "${var.name}-ring"
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
  source = "../../modules/artesca-application-bucket"

  account_name        = module.account.account_name
  bucket_name         = "${var.name}-data"
  location_constraint = module.location.name
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
