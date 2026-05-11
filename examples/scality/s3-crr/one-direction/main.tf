# One-direction CRR example: source → dest.
#
# Chains the wrapper modules end-to-end so a single `tofu apply`
# stands up the full feature: accounts, operators, buckets, IAM,
# replication wiring, and verification users.
#
# To switch to active-active, see ../bidirectional/.

# ============================================================
# Source cluster
# ============================================================

module "source_account" {
  source    = "../../../../modules/scality/scality-account-management"
  providers = { scality = scality }

  account_name  = "crr-source"
  account_email = "crr-source@example.com"
  console_login = false
}

module "source_operator" {
  source    = "../../../../modules/scality/account-operator"
  providers = { scality = scality }

  account_access_key = module.source_account.access_key
  account_secret_key = module.source_account.secret_key
}

module "source_bucket" {
  source    = "../../../../modules/scality/application-bucket"
  providers = { scality = scality }

  account_access_key = module.source_operator.access_key
  account_secret_key = module.source_operator.secret_key
  bucket_name        = "crr-source-data"
}

# ============================================================
# Destination cluster
# ============================================================

module "dest_account" {
  source    = "../../../../modules/scality/scality-account-management"
  providers = { scality = scality.dest }

  account_name  = "crr-dest"
  account_email = "crr-dest@example.com"
  console_login = false
}

module "dest_operator" {
  source    = "../../../../modules/scality/account-operator"
  providers = { scality = scality.dest }

  account_access_key = module.dest_account.access_key
  account_secret_key = module.dest_account.secret_key
}

module "dest_bucket" {
  source    = "../../../../modules/scality/application-bucket"
  providers = { scality = scality.dest }

  account_access_key = module.dest_operator.access_key
  account_secret_key = module.dest_operator.secret_key
  bucket_name        = "crr-dest-data"
}

# ============================================================
# Cross-region replication — source → dest only
# ============================================================

module "crr" {
  source = "../../../../modules/scality/s3-crr"

  providers = {
    scality.source = scality
    scality.dest   = scality.dest
  }

  source_account_access_key = module.source_operator.access_key
  source_account_secret_key = module.source_operator.secret_key
  source_bucket_name        = module.source_bucket.bucket_name

  dest_account_access_key = module.dest_operator.access_key
  dest_account_secret_key = module.dest_operator.secret_key
  dest_bucket_name        = module.dest_bucket.bucket_name
}

# ============================================================
# Verification users — writer on source, reader on dest, so you
# can confirm objects ship across after apply.
# ============================================================

module "source_writer" {
  source    = "../../../../modules/scality/application-identity"
  providers = { scality = scality }

  account_access_key = module.source_operator.access_key
  account_secret_key = module.source_operator.secret_key

  username       = "crr-source-writer"
  bucket_arns    = [module.source_bucket.bucket_arn]
  access_pattern = "read-write"
}

module "dest_reader" {
  source    = "../../../../modules/scality/application-identity"
  providers = { scality = scality.dest }

  account_access_key = module.dest_operator.access_key
  account_secret_key = module.dest_operator.secret_key

  username       = "crr-dest-reader"
  bucket_arns    = [module.dest_bucket.bucket_arn]
  access_pattern = "read-only"
}
