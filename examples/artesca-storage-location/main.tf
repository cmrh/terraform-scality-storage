# ARTESCA storage location example: a RING bucket as an ARTESCA location.
#
# RING:    account -> operator -> versioned bucket + key (ring-replication-target)
# ARTESCA: RING S3 location using that bucket and key

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
# ARTESCA_PASSWORD.
provider "artesca" {}

variable "name" {
  type        = string
  default     = "ring-location-01"
  description = "Base name for the RING account, bucket and location. Override (TF_VAR_name) to avoid collisions."
}

variable "endpoint_hostname" {
  type        = string
  default     = null
  description = "Optional hostname for an ARTESCA S3 endpoint serving the location."
}

variable "ring_endpoint" {
  type        = string
  description = "RING S3 endpoint, as ARTESCA reaches it."
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
  bucket_name        = "${var.name}-target"
}

module "location" {
  source = "../../modules/artesca-storage-location"

  name        = var.name
  type        = "ring-s3"
  endpoint    = var.ring_endpoint
  bucket_name = module.ring_bucket.bucket_name
  access_key  = module.ring_bucket.access_key
  secret_key  = module.ring_bucket.secret_key

  endpoint_hostname = var.endpoint_hostname
}

output "location_name" {
  value = module.location.name
}
