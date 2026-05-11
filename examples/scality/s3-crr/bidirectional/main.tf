# Bidirectional (active-active) CRR example.
#
# Stands up the full feature on two Scality clusters with replication
# in both directions. Versus the one-direction example, this differs
# in a single line: `bidirectional = true` on the s3-crr module call.
# The IAM roles and policies are symmetric, so nothing else changes.

# ============================================================
# Source cluster
# ============================================================

module "source_account" {
  source    = "../../../../modules/scality/scality-account-management"
  providers = { scality = scality }

  account_name  = "crr-bidir-source"
  account_email = "crr-bidir-source@example.com"
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
  bucket_name        = "crr-bidir-source-data"
}

# ============================================================
# Destination cluster
# ============================================================

module "dest_account" {
  source    = "../../../../modules/scality/scality-account-management"
  providers = { scality = scality.dest }

  account_name  = "crr-bidir-dest"
  account_email = "crr-bidir-dest@example.com"
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
  bucket_name        = "crr-bidir-dest-data"
}

# ============================================================
# Cross-region replication — bidirectional
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

  bidirectional = true
}

# ============================================================
# Verification users — writer on each side, so you can confirm
# replication in both directions after apply.
# ============================================================

module "source_writer" {
  source    = "../../../../modules/scality/application-identity"
  providers = { scality = scality }

  account_access_key = module.source_operator.access_key
  account_secret_key = module.source_operator.secret_key

  username       = "crr-bidir-source-writer"
  bucket_arns    = [module.source_bucket.bucket_arn]
  access_pattern = "read-write"
}

module "dest_writer" {
  source    = "../../../../modules/scality/application-identity"
  providers = { scality = scality.dest }

  account_access_key = module.dest_operator.access_key
  account_secret_key = module.dest_operator.secret_key

  username       = "crr-bidir-dest-writer"
  bucket_arns    = [module.dest_bucket.bucket_arn]
  access_pattern = "read-write"
}
