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

  # The preset or policy_document policy, created only when one is given.
  single_policy    = var.policy_document != null || length(var.bucket_arns) > 0
  effective_policy = !local.single_policy ? null : var.policy_document != null ? var.policy_document : local.preset_policies[var.access_pattern]
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
  count = local.single_policy ? 1 : 0

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  username           = scality_user.this.username
  policy_name        = local.policy_name
  policy_document    = local.effective_policy

  lifecycle {
    precondition {
      condition     = !contains(keys(var.policies), local.policy_name)
      error_message = "policies can't contain the name of the preset or policy_document policy (policy_name, default \"<username>-policy\")."
    }
  }
}

# Releases before the count was added managed the policy as a single instance.
moved {
  from = scality_user_policy.this
  to   = scality_user_policy.this[0]
}

resource "scality_user_policy" "policies" {
  for_each = var.policies

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  username           = scality_user.this.username
  policy_name        = each.key
  policy_document    = each.value
}

# Managed policies, attached by ARN. Reference the policy (for example
# scality_iam_policy.x.arn) so destroy detaches it before deleting the policy.
resource "scality_iam_user_policy_attachment" "this" {
  for_each = var.policy_arns

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  username           = scality_user.this.username
  policy_arn         = each.value
}
