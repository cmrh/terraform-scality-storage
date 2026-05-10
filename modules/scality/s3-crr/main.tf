locals {
  source_bucket_arn = "arn:aws:s3:::${var.source_bucket_name}"
  dest_bucket_arn   = "arn:aws:s3:::${var.dest_bucket_name}"

  # Internal CRR operator user — fixed name; the customer-facing pattern
  # for application or verification access is to create a separate user
  # via the application-identity module.
  crr_operator_username = "crr-operator"

  # Backbeat assumes the IAM role to perform replication on each side.
  backbeat_trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backbeat" }
      Action    = "sts:AssumeRole"
    }]
  })

  # Identical action set on both sides. Each side's policy scopes the
  # resource to its OWN local bucket only — the role-pair on
  # scality_bucket_replication handles cross-cluster routing.
  replication_actions = [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:GetObjectVersionAcl",
    "s3:GetObjectTagging",
    "s3:ListBucket",
    "s3:GetReplicationConfiguration",
    "s3:ReplicateObject",
    "s3:ReplicateDelete",
    "s3:ReplicateTags",
    "s3:PutObject",
  ]
}

# --- Source-side IAM ---

resource "scality_iam_policy" "source" {
  provider = scality.source

  account_access_key = var.source_account_access_key
  account_secret_key = var.source_account_secret_key
  policy_name        = var.policy_name
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = local.replication_actions
      Resource = [
        local.source_bucket_arn,
        "${local.source_bucket_arn}/*",
      ]
    }]
  })
}

resource "scality_iam_role" "source" {
  provider = scality.source

  account_access_key = var.source_account_access_key
  account_secret_key = var.source_account_secret_key
  role_name          = var.role_name
  assume_role_policy = local.backbeat_trust_policy
}

resource "scality_iam_role_policy_attachment" "source" {
  provider = scality.source

  account_access_key = var.source_account_access_key
  account_secret_key = var.source_account_secret_key
  role_name          = scality_iam_role.source.role_name
  policy_arn         = scality_iam_policy.source.arn
}

# --- Destination-side IAM ---

resource "scality_iam_policy" "dest" {
  provider = scality.dest

  account_access_key = var.dest_account_access_key
  account_secret_key = var.dest_account_secret_key
  policy_name        = var.policy_name
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = local.replication_actions
      Resource = [
        local.dest_bucket_arn,
        "${local.dest_bucket_arn}/*",
      ]
    }]
  })
}

resource "scality_iam_role" "dest" {
  provider = scality.dest

  account_access_key = var.dest_account_access_key
  account_secret_key = var.dest_account_secret_key
  role_name          = var.role_name
  assume_role_policy = local.backbeat_trust_policy
}

resource "scality_iam_role_policy_attachment" "dest" {
  provider = scality.dest

  account_access_key = var.dest_account_access_key
  account_secret_key = var.dest_account_secret_key
  role_name          = scality_iam_role.dest.role_name
  policy_arn         = scality_iam_policy.dest.arn
}

# --- Replication: source → dest (always) ---

resource "scality_bucket_replication" "source_to_dest" {
  provider = scality.source

  account_access_key = var.source_account_access_key
  account_secret_key = var.source_account_secret_key
  bucket             = var.source_bucket_name
  role               = "${scality_iam_role.source.arn},${scality_iam_role.dest.arn}"

  rule {
    status             = "Enabled"
    prefix             = ""
    destination_bucket = local.dest_bucket_arn
  }

  depends_on = [
    scality_iam_role_policy_attachment.source,
    scality_iam_role_policy_attachment.dest,
  ]
}

# --- Replication: dest → source (when bidirectional) ---

resource "scality_bucket_replication" "dest_to_source" {
  count    = var.bidirectional ? 1 : 0
  provider = scality.dest

  account_access_key = var.dest_account_access_key
  account_secret_key = var.dest_account_secret_key
  bucket             = var.dest_bucket_name
  role               = "${scality_iam_role.dest.arn},${scality_iam_role.source.arn}"

  rule {
    status             = "Enabled"
    prefix             = ""
    destination_bucket = local.source_bucket_arn
  }

  depends_on = [
    scality_iam_role_policy_attachment.source,
    scality_iam_role_policy_attachment.dest,
  ]
}

# --- CRR operator user on the source cluster (internal) ---

resource "scality_user" "source_crr_operator" {
  provider = scality.source

  account_access_key = var.source_account_access_key
  account_secret_key = var.source_account_secret_key
  username           = local.crr_operator_username
}

resource "scality_user_policy" "source_crr_operator" {
  provider = scality.source

  account_access_key = var.source_account_access_key
  account_secret_key = var.source_account_secret_key
  username           = scality_user.source_crr_operator.username
  policy_name        = "${local.crr_operator_username}-policy"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${local.source_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = local.source_bucket_arn
      },
    ]
  })
}

resource "scality_user_access_key" "source_crr_operator" {
  provider = scality.source

  account_access_key = var.source_account_access_key
  account_secret_key = var.source_account_secret_key
  username           = scality_user.source_crr_operator.username
}

# --- CRR operator user on the destination cluster (internal) ---

resource "scality_user" "dest_crr_operator" {
  provider = scality.dest

  account_access_key = var.dest_account_access_key
  account_secret_key = var.dest_account_secret_key
  username           = local.crr_operator_username
}

resource "scality_user_policy" "dest_crr_operator" {
  provider = scality.dest

  account_access_key = var.dest_account_access_key
  account_secret_key = var.dest_account_secret_key
  username           = scality_user.dest_crr_operator.username
  policy_name        = "${local.crr_operator_username}-policy"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${local.dest_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = local.dest_bucket_arn
      },
    ]
  })
}

resource "scality_user_access_key" "dest_crr_operator" {
  provider = scality.dest

  account_access_key = var.dest_account_access_key
  account_secret_key = var.dest_account_secret_key
  username           = scality_user.dest_crr_operator.username
}
