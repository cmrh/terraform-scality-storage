# ARTESCA storage location example: a Scality S3 bucket as an ARTESCA location.
#
# Scality S3:    account -> operator -> versioned bucket + key (scality-ring-s3-target)
# ARTESCA: RING S3 location using that bucket and key

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.2"
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
  description = "Base name for the Scality S3 account, bucket and location. Override (TF_VAR_name) to avoid collisions."
}

variable "endpoint_hostname" {
  type        = string
  default     = null
  description = "Optional hostname for an ARTESCA S3 endpoint serving the location."
}

variable "ring_s3_endpoint" {
  type        = string
  description = "Scality S3 endpoint, as ARTESCA reaches it."
}

module "ring_s3_account" {
  source = "../../modules/scality-account-management"

  account_name  = "${var.name}-ring"
  account_email = "${var.name}-ring@example.com"
  console_login = false
}

module "ring_s3_operator" {
  source = "../../modules/scality-account-operator"

  account_access_key = module.ring_s3_account.access_key
  account_secret_key = module.ring_s3_account.secret_key
}

module "ring_s3_bucket" {
  source = "../../modules/scality-ring-s3-target"

  account_access_key = module.ring_s3_operator.access_key
  account_secret_key = module.ring_s3_operator.secret_key
  bucket_name        = "${var.name}-target"
}

module "location" {
  source = "../../modules/artesca-storage-location"

  name        = var.name
  type        = "ring-s3"
  endpoint    = var.ring_s3_endpoint
  bucket_name = module.ring_s3_bucket.bucket_name
  access_key  = module.ring_s3_bucket.access_key
  secret_key  = module.ring_s3_bucket.secret_key

  endpoint_hostname = var.endpoint_hostname
}

output "location_name" {
  value = module.location.name
}
