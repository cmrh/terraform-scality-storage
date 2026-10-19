terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
  }
}

# Platform (superadmin) credentials for account creation. The provider reads
# SCALITY_ENDPOINT, SCALITY_ACCESS_KEY, SCALITY_SECRET_KEY from the
# environment. Everything inside the accounts uses each account's own keys.
provider "scality" {}
