resource "artesca_account" "this" {
  name  = var.account_name
  email = var.account_email
}

resource "artesca_bucket" "this" {
  account_name       = artesca_account.this.name
  name               = var.bucket_name
  versioning_enabled = true
  force_destroy      = var.force_destroy
}

resource "artesca_user" "this" {
  for_each = var.users

  account_name  = artesca_account.this.name
  username      = each.key
  force_destroy = var.force_destroy
}

resource "artesca_user_policy" "this" {
  for_each = var.users

  account_name = artesca_account.this.name
  username     = artesca_user.this[each.key].username
  policy_name  = "${var.bucket_name}-rw"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ObjectReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
        ]
        Resource = ["arn:aws:s3:::${var.bucket_name}/*"]
      },
      {
        Sid      = "BucketList"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketVersions"]
        Resource = ["arn:aws:s3:::${var.bucket_name}"]
      },
    ]
  })
}

resource "artesca_user_access_key" "this" {
  for_each = var.users

  account_name = artesca_account.this.name
  username     = artesca_user.this[each.key].username
}

resource "artesca_location" "ring" {
  name          = var.location_name
  location_type = "location-scality-ring-s3-v1"

  details {
    endpoint     = var.ring_endpoint
    bucket_name  = var.ring_bucket_name
    bucket_match = true
    access_key   = var.ring_access_key
    secret_key   = var.ring_secret_key
  }
}

resource "artesca_bucket_workflow_replication" "this" {
  account_name         = artesca_account.this.name
  bucket_name          = artesca_bucket.this.name
  destination_location = artesca_location.ring.name
  enabled              = var.replication_enabled
}
