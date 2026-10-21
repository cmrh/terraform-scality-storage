locals {
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"

  # What ARTESCA's RING location needs, by purpose:
  # - replication: checks the bucket's versioning and location when the
  #   location is created, and writes replicas with PutObject.
  # - tiering: the data lives only on RING, so ARTESCA also reads it back
  #   and deletes it there.
  actions = {
    replication = ["s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:PutObject"]
    tiering = [
      "s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:PutObject",
      "s3:GetObject", "s3:GetObjectVersion", "s3:DeleteObject", "s3:DeleteObjectVersion",
    ]
  }

  location_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ArtescaLocation"
      Effect   = "Allow"
      Action   = local.actions[var.purpose]
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
  policy_document    = local.location_policy
}
