# IAM Policy for CRR on Source
resource "aws_iam_policy" "source_crr" {
  provider = aws.source
  name     = local.policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.source_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetReplicationConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::${var.source_bucket_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "arn:aws:s3:::${var.destination_bucket_name}/*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = local.policy_name
      Purpose     = "CRR-Source"
      ManagedBy   = "Terraform"
      Source      = var.source_bucket_name
      Destination = var.destination_bucket_name
    }
  )
}

# IAM Policy for CRR on Destination
resource "aws_iam_policy" "destination_crr" {
  provider = aws.destination
  name     = local.policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl"
        ]
        Resource = [
          "arn:aws:s3:::${var.source_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetReplicationConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::${var.source_bucket_name}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "arn:aws:s3:::${var.destination_bucket_name}/*"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = local.policy_name
      Purpose     = "CRR-Destination"
      ManagedBy   = "Terraform"
      Source      = var.source_bucket_name
      Destination = var.destination_bucket_name
    }
  )
}

# IAM Trust Role on Source
resource "aws_iam_role" "source_crr" {
  provider = aws.source
  name     = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = var.assume_role_principal
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = local.role_name
      Purpose     = "CRR-Source-Role"
      ManagedBy   = "Terraform"
      Source      = var.source_bucket_name
      Destination = var.destination_bucket_name
    }
  )
}

# IAM Trust Role on Destination
resource "aws_iam_role" "destination_crr" {
  provider = aws.destination
  name     = local.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = var.assume_role_principal
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name        = local.role_name
      Purpose     = "CRR-Destination-Role"
      ManagedBy   = "Terraform"
      Source      = var.source_bucket_name
      Destination = var.destination_bucket_name
    }
  )
}

# Attach Policy to Source Role
resource "aws_iam_role_policy_attachment" "source_crr" {
  provider   = aws.source
  role       = aws_iam_role.source_crr.name
  policy_arn = aws_iam_policy.source_crr.arn
}

# Attach Policy to Destination Role
resource "aws_iam_role_policy_attachment" "destination_crr" {
  provider   = aws.destination
  role       = aws_iam_role.destination_crr.name
  policy_arn = aws_iam_policy.destination_crr.arn
}
