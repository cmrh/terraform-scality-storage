# ARTESCA edge replicating to Scality S3.
#
# Scality S3:    account -> operator -> versioned target bucket + replication user
# ARTESCA: account + users -> versioned bucket -> RING S3 location -> replication

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.3"
    }
    artesca = {
      source = "cmrh/artesca"
      # 1.2.1 fixes in-place updates of CRR locations.
      version = ">= 1.2.1, < 2.0.0"
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

variable "mode" {
  type        = string
  default     = "ring-s3"
  description = "\"ring-s3\" (RING S3 location with a write-only key) or \"crr\" (CRR location over STS with a destination role)."
}

variable "ring_s3_sts_endpoint" {
  type        = string
  default     = null
  description = "Scality S3 STS endpoint, as ARTESCA reaches it. Required for mode = \"crr\"."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Set true and apply before destroying, so the ARTESCA bucket and users can be deleted."
}

variable "ring_s3_endpoint" {
  type        = string
  description = "Scality S3 endpoint that ARTESCA replicates to."
}

module "ring_s3_account" {
  source = "../../modules/scality-account-management"

  account_name  = "${var.name}-ring"
  account_email = "${var.name}-ring@edge.example.com"
  console_login = false
}

module "ring_s3_operator" {
  source = "../../modules/scality-account-operator"

  account_access_key = module.ring_s3_account.access_key
  account_secret_key = module.ring_s3_account.secret_key
}

module "ring_s3_target" {
  source = "../../modules/scality-ring-s3-target"

  account_access_key = module.ring_s3_operator.access_key
  account_secret_key = module.ring_s3_operator.secret_key
  bucket_name        = "${var.name}-replica"
  purpose            = var.mode == "crr" ? "crr" : "replication"
}

module "edge" {
  source = "../../modules/artesca-edge-replication"

  account_name  = var.name
  account_email = "${var.name}@edge.example.com"
  bucket_name   = "${var.name}-data"
  users         = ["${var.name}-app"]

  mode                 = var.mode
  ring_s3_sts_endpoint = var.ring_s3_sts_endpoint
  ring_s3_role_arn     = module.ring_s3_target.role_arn

  location_name       = "${var.name}-ring"
  ring_s3_endpoint    = var.ring_s3_endpoint
  ring_s3_bucket_name = module.ring_s3_target.bucket_name
  force_destroy       = var.force_destroy
  ring_s3_access_key  = module.ring_s3_target.access_key
  ring_s3_secret_key  = module.ring_s3_target.secret_key
}

output "edge_bucket" {
  value = module.edge.bucket_name
}

output "ring_s3_bucket" {
  value = module.ring_s3_target.bucket_name
}

output "app_keys" {
  value     = module.edge.user_access_keys
  sensitive = true
}

output "ring_s3_operator_access_key" {
  value     = module.ring_s3_operator.access_key
  sensitive = true
}

output "ring_s3_operator_secret_key" {
  value     = module.ring_s3_operator.secret_key
  sensitive = true
}
