locals {
  location_types = {
    "ring-s3"      = "location-scality-ring-s3-v1"
    "versity-tape" = "location-versity-tape-archive-v1"
  }
}

resource "artesca_location" "this" {
  name          = var.name
  location_type = local.location_types[var.type]
  size_limit_gb = var.size_limit_gb

  details {
    endpoint     = var.endpoint
    bucket_name  = var.bucket_name
    bucket_match = var.bucket_match
    access_key   = var.access_key
    secret_key   = var.secret_key
  }

  lifecycle {
    precondition {
      condition     = var.type != "versity-tape" || startswith(var.endpoint, "https://")
      error_message = "A versity-tape location needs an https:// endpoint; ARTESCA uses TLS to reach cold backends."
    }
  }
}

resource "artesca_endpoint" "this" {
  count = var.endpoint_hostname == null ? 0 : 1

  hostname      = var.endpoint_hostname
  location_name = artesca_location.this.name
}
