locals {
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"

  # ARTESCA's RING location needs only these: it reads the bucket's
  # versioning and location when the location is created, and writes
  # replicas with PutObject.
  replication_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ArtescaReplication"
      Effect   = "Allow"
      Action   = ["s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:PutObject"]
      Resource = [local.bucket_arn, "${local.bucket_arn}/*"]
    }]
  })
}

resource "scality_bucket" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  bucket             = var.bucket_name
  versioning         = true
  tags               = var.tags
}

module "replication_user" {
  source = "../scality-application-identity"

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  username           = var.username
  policy_name        = var.policy_name
  policy_document    = local.replication_policy
}
