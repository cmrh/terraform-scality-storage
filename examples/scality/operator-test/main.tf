# Operator-pattern lifecycle example.
#
# Stands up an account, creates the operator user with account-root,
# then has the operator stand up a bucket and an application user
# (read-write on the bucket). Exists as both a runnable demo and the
# regression test wired into the integration workflow — confirms the
# operator pattern works end-to-end under both apply and destroy.

locals {
  account_attributes = {
    customer_name = var.account_name
  }
}

module "account" {
  source = "../../../modules/scality/scality-account-management"

  account_name       = var.account_name
  account_email      = "${var.account_name}@operator-test.example.com"
  console_login      = false
  account_attributes = local.account_attributes
}

module "operator" {
  source = "../../../modules/scality/account-operator"

  # Operator created with account-root (bootstrap) keys.
  account_access_key = module.account.access_key
  account_secret_key = module.account.secret_key
}

module "bucket" {
  source = "../../../modules/scality/application-bucket"

  # Bucket created by the operator.
  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key
  bucket_name        = "${var.account_name}-data"
}

module "app_user" {
  source = "../../../modules/scality/application-identity"

  # Application user created by the operator with read-write on the bucket.
  account_access_key = module.operator.access_key
  account_secret_key = module.operator.secret_key

  username       = "${var.account_name}-app"
  bucket_arns    = [module.bucket.bucket_arn]
  access_pattern = "read-write"
}
