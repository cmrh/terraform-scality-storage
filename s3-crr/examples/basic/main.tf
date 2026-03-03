terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# ============================================================================
# SOURCE PROVIDER - Manages resources on the source Scality endpoint
# ============================================================================
# NOTE: Both providers use "aws" type (S3-compatible) but different aliases
provider "aws" {
  alias      = "source"  # Referenced as "aws.source"
  region     = var.source_region
  access_key = var.source_access_key
  secret_key = var.source_secret_key

  endpoints {
    s3  = var.source_endpoint
    iam = var.source_endpoint
    sts = var.source_endpoint
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = false
  s3_use_path_style          = true
}

# ============================================================================
# DESTINATION PROVIDER - Manages resources on the destination Scality endpoint
# ============================================================================
# NOTE: Both providers use "aws" type (S3-compatible) but different aliases
provider "aws" {
  alias      = "destination"  # Referenced as "aws.destination"
  region     = var.destination_region
  access_key = var.destination_access_key
  secret_key = var.destination_secret_key

  endpoints {
    s3  = var.destination_endpoint
    iam = var.destination_endpoint
    sts = var.destination_endpoint
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = false
  s3_use_path_style          = true
}

# Call the S3 CRR module
module "s3_crr" {
  source = "../../"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  # Bucket names
  source_bucket_name      = var.source_bucket_name
  destination_bucket_name = var.destination_bucket_name

  # Endpoints
  source_endpoint      = var.source_endpoint
  destination_endpoint = var.destination_endpoint

  # Credentials (passed through from variables)
  source_access_key      = var.source_access_key
  source_secret_key      = var.source_secret_key
  destination_access_key = var.destination_access_key
  destination_secret_key = var.destination_secret_key

  # Regions
  source_region      = var.source_region
  destination_region = var.destination_region

  # Create buckets if they don't exist
  create_source_bucket      = var.create_source_bucket
  create_destination_bucket = var.create_destination_bucket

  # Optional custom names
  policy_name = var.policy_name
  role_name   = var.role_name

  # Replication configuration
  replication_prefix = var.replication_prefix
  replication_status = var.replication_status

  # Tags
  tags = var.tags
}
