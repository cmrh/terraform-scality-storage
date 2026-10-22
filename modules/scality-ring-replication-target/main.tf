locals {
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"

  # What ARTESCA's RING location needs, by purpose:
  # - replication: checks the bucket's versioning and location when the
  #   location is created, and writes replicas with PutObject.
  # - tiering: the data lives only on RING, so ARTESCA also reads it back
  #   and deletes it there.
  # - crr: the key only assumes the destination role; the role writes the
  #   replicas.
  actions = {
    replication = ["s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:PutObject"]
    tiering = [
      "s3:GetBucketVersioning", "s3:GetBucketLocation", "s3:PutObject",
      "s3:GetObject", "s3:GetObjectVersion", "s3:DeleteObject", "s3:DeleteObjectVersion",
    ]
  }

  location_policy = var.purpose == "crr" ? jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeDestinationRole"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = scality_iam_role.crr[0].arn
    }]
    }) : jsonencode({
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

# --- crr: destination role assumed by the location's key over STS ---

resource "scality_iam_policy" "crr" {
  count = var.purpose == "crr" ? 1 : 0

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  policy_name        = "${var.role_name}-replicate"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "WriteReplicas"
      Effect   = "Allow"
      Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
      Resource = [local.bucket_arn, "${local.bucket_arn}/*"]
    }]
  })
}

resource "scality_iam_role" "crr" {
  count = var.purpose == "crr" ? 1 : 0

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  role_name          = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = module.replication_user.user_arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "scality_iam_role_policy_attachment" "crr" {
  count = var.purpose == "crr" ? 1 : 0

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  role_name          = scality_iam_role.crr[0].role_name
  policy_arn         = scality_iam_policy.crr[0].arn

  # A trust change replaces the role under the same name; replace the
  # attachment with it so the old role can be deleted.
  lifecycle {
    replace_triggered_by = [scality_iam_role.crr]
  }
}
