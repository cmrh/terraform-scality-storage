variable "account_name" {
  type        = string
  default     = "operator-test-01"
  description = "Account name to create. Override in CI (TF_VAR_account_name) to avoid collisions across concurrent runs."
}

terraform {
  required_version = ">= 1.0"

  required_providers {
    scality = {
      source  = "scality/scality"
      version = "~> 0.4"
    }
  }
}

# Provider reads SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY
# from the environment.
provider "scality" {}
