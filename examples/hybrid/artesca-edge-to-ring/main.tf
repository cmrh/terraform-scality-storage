# ARTESCA edge replicating to RING.
#
# RING:    account -> operator -> versioned target bucket + replication user
# ARTESCA: account + users -> versioned bucket -> RING location -> replication

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
  default     = "edge-01"
  description = "Base name for the accounts, buckets and location. Override (TF_VAR_name) to avoid collisions."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Set true and apply before destroying, so the ARTESCA bucket and users can be deleted."
}

variable "ring_endpoint" {
  type        = string
  description = "RING S3 endpoint that ARTESCA replicates to."
}

module "ring_account" {
  source = "../../../modules/scality/scality-account-management"

  account_name  = "${var.name}-ring"
  account_email = "${var.name}-ring@edge.example.com"
  console_login = false
}

module "ring_operator" {
  source = "../../../modules/scality/account-operator"

  account_access_key = module.ring_account.access_key
  account_secret_key = module.ring_account.secret_key
}

module "ring_target" {
  source = "../../../modules/scality/ring-replication-target"

  account_access_key = module.ring_operator.access_key
  account_secret_key = module.ring_operator.secret_key
  bucket_name        = "${var.name}-replica"
}

module "edge" {
  source = "../../../modules/artesca/edge-replication"

  account_name  = var.name
  account_email = "${var.name}@edge.example.com"
  bucket_name   = "${var.name}-data"
  users         = ["${var.name}-app"]

  location_name    = "${var.name}-ring"
  ring_endpoint    = var.ring_endpoint
  ring_bucket_name = module.ring_target.bucket_name
  force_destroy    = var.force_destroy
  ring_access_key  = module.ring_target.access_key
  ring_secret_key  = module.ring_target.secret_key
}

output "edge_bucket" {
  value = module.edge.bucket_name
}

output "ring_bucket" {
  value = module.ring_target.bucket_name
}

output "app_keys" {
  value     = module.edge.user_access_keys
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
