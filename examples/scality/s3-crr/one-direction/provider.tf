variable "dest_endpoint" {
  type        = string
  description = "HTTPS endpoint of the destination cluster (e.g., https://s3.dest.example.com)."
}

variable "dest_access_key" {
  type        = string
  sensitive   = true
  description = "Cluster-level admin access key on the destination, used by the provider to create the destination account."
}

variable "dest_secret_key" {
  type        = string
  sensitive   = true
  description = "Cluster-level admin secret key paired with dest_access_key."
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    scality = {
      source = "scality/scality"
      # Pin to a tag in production, e.g. version = "~> 0.4"
    }
  }
}

# Source cluster — provider reads SCALITY_ENDPOINT, SCALITY_ACCESS_KEY,
# SCALITY_SECRET_KEY from the environment.
provider "scality" {
}

# Destination cluster — explicit endpoint + credentials.
provider "scality" {
  alias      = "dest"
  endpoint   = var.dest_endpoint
  access_key = var.dest_access_key
  secret_key = var.dest_secret_key
}
