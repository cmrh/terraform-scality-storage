locals {
  policy_name = var.policy_name != null ? var.policy_name : "${var.username}-policy"

  # Pre-canned policy presets. Each scopes access to var.bucket_arns only —
  # never grants `*` resource. Customers needing more nuanced policies use
  # the policy_document override.
  preset_policies = {
    "read-only" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ObjectRead"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:GetObjectVersion"]
          Resource = [for arn in var.bucket_arns : "${arn}/*"]
        },
        {
          Sid      = "BucketList"
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketVersions"]
          Resource = var.bucket_arns
        },
      ]
    })

    "read-write" = jsonencode({
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
          Resource = [for arn in var.bucket_arns : "${arn}/*"]
        },
        {
          Sid      = "BucketList"
          Effect   = "Allow"
          Action   = ["s3:ListBucket", "s3:GetBucketLocation", "s3:ListBucketVersions"]
          Resource = var.bucket_arns
        },
      ]
    })

    "bucket-admin" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "BucketFullAccess"
          Effect   = "Allow"
          Action   = "s3:*"
          Resource = concat(var.bucket_arns, [for arn in var.bucket_arns : "${arn}/*"])
        },
      ]
    })
  }

  effective_policy = var.policy_document != null ? var.policy_document : local.preset_policies[var.access_pattern]
}

resource "scality_user" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  username           = var.username
}

resource "scality_user_access_key" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  username           = scality_user.this.username
}

resource "scality_user_policy" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  username           = scality_user.this.username
  policy_name        = local.policy_name
  policy_document    = local.effective_policy

  lifecycle {
    precondition {
      condition     = var.policy_document != null || length(var.bucket_arns) > 0
      error_message = "Provide either bucket_arns (with the chosen access_pattern preset) or a custom policy_document."
    }
  }
}
