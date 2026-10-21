module "account" {
  source = "../artesca-account-management"

  account_name  = var.account_name
  account_email = var.account_email
}

# Versioned, so earlier state versions can be recovered.
module "bucket" {
  source = "../artesca-application-bucket"

  account_name = module.account.account_name
  bucket_name  = var.bucket_name
  tags         = var.tags
}

module "state_user" {
  source = "../artesca-application-identity"

  account_name   = module.account.account_name
  username       = var.username
  access_pattern = "read-write"
  bucket_arns    = [module.bucket.bucket_arn]
}
