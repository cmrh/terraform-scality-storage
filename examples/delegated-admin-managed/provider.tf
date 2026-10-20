terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
  }
}

# One aliased provider per sub-account, each assuming that sub-account's
# delegated-admin role with the management user's keys. The endpoint comes
# from SCALITY_ENDPOINT. The keys are set explicitly so this stage never
# runs as whatever SCALITY_ACCESS_KEY happens to hold.
#
# Adding a sub-account: add it to the bootstrap's sub_accounts, apply the
# bootstrap, then add a provider block here.

provider "scality" {
  alias      = "customer_a"
  access_key = var.delegator_access_key
  secret_key = var.delegator_secret_key

  assume_role {
    role_arn     = var.role_arns["customer-a"]
    session_name = "delegated-admin"
  }
}

provider "scality" {
  alias      = "customer_b"
  access_key = var.delegator_access_key
  secret_key = var.delegator_secret_key

  assume_role {
    role_arn     = var.role_arns["customer-b"]
    session_name = "delegated-admin"
  }
}
