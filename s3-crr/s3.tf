# Source Bucket
resource "aws_s3_bucket" "source" {
  count    = var.create_source_bucket ? 1 : 0
  provider = aws.source
  bucket   = var.source_bucket_name

  tags = merge(
    var.tags,
    {
      Name      = var.source_bucket_name
      Role      = "CRR-Source"
      ManagedBy = "Terraform"
    }
  )
}

# Destination Bucket
resource "aws_s3_bucket" "destination" {
  count    = var.create_destination_bucket ? 1 : 0
  provider = aws.destination
  bucket   = var.destination_bucket_name

  tags = merge(
    var.tags,
    {
      Name      = var.destination_bucket_name
      Role      = "CRR-Destination"
      ManagedBy = "Terraform"
    }
  )
}

# Enable versioning on source bucket
resource "aws_s3_bucket_versioning" "source" {
  provider = aws.source
  bucket   = var.source_bucket_name

  versioning_configuration {
    status = "Enabled"
  }

  # Ensure bucket exists before configuring versioning
  depends_on = [aws_s3_bucket.source]
}

# Enable versioning on destination bucket
resource "aws_s3_bucket_versioning" "destination" {
  provider = aws.destination
  bucket   = var.destination_bucket_name

  versioning_configuration {
    status = "Enabled"
  }

  # Ensure bucket exists before configuring versioning
  depends_on = [aws_s3_bucket.destination]
}

# Replication configuration on source bucket
resource "aws_s3_bucket_replication_configuration" "source" {
  provider = aws.source
  bucket   = var.source_bucket_name
  role     = "arn:aws:iam::${local.source_account_id}:role/${local.role_name},arn:aws:iam::${local.destination_account_id}:role/${local.role_name}"

  rule {
    id     = "replicate-all"
    status = var.replication_status

    filter {
      prefix = var.replication_prefix
    }

    destination {
      bucket = "arn:aws:s3:::${var.destination_bucket_name}"
    }
  }

  # Ensure dependencies are created first
  depends_on = [
    aws_s3_bucket_versioning.source,
    aws_s3_bucket_versioning.destination,
    aws_iam_role.source_crr,
    aws_iam_role.destination_crr,
    aws_iam_role_policy_attachment.source_crr,
    aws_iam_role_policy_attachment.destination_crr
  ]
}
