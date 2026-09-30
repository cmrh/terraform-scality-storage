locals {
  policy_name = var.policy_name != null ? var.policy_name : "${var.role_name}-perms"

  default_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "SubAccountAdmin"
      Effect   = "Allow"
      Action   = ["s3:*", "iam:*"]
      Resource = "*"
    }]
  })

  effective_policy = var.policy_document != null ? var.policy_document : local.default_policy
}

resource "scality_iam_policy" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  policy_name        = local.policy_name
  policy_document    = local.effective_policy
}

resource "scality_iam_role" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  role_name          = var.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.trusted_user_arn }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "scality_iam_role_policy_attachment" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  role_name          = scality_iam_role.this.role_name
  policy_arn         = scality_iam_policy.this.arn

  # Every role attribute forces replacement (e.g. a trust-policy edit), but
  # role_name is unchanged, so the attachment would otherwise stay put and
  # the old role's delete fails with DeleteConflict ("must detach all
  # policies first"). Replacing the attachment with the role detaches it
  # before the delete and re-attaches it to the new role.
  lifecycle {
    replace_triggered_by = [scality_iam_role.this]
  }
}
