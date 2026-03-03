terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Initially uses local backend
  # After creating the bucket, migrate to S3 backend by uncommenting below:
  #
  # backend "s3" {
  #   bucket   = "terraform-state"
  #   key      = "bootstrap/terraform.tfstate"
  #   region   = "us-east-1"
  #   endpoint = "http://10.164.169.247"
  #
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   force_path_style            = true
  # }
}

# Configure AWS provider to use Scality S3 endpoint
provider "aws" {
  region = "us-east-1"

  endpoints {
    s3  = var.scality_endpoint
    sts = var.scality_endpoint
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  # Allow HTTP for local/development deployments
  insecure = var.use_https ? false : true
}

# Create S3 bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  tags = merge(
    var.tags,
    {
      Name      = "Terraform State Bucket"
      Purpose   = "terraform-state"
      ManagedBy = "terraform-bootstrap"
    }
  )
}

# Enable versioning for state bucket (essential for recovery)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Optional: Enable server-side encryption (if supported by Scality)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Optional: Create lifecycle rule for old state versions
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.old_version_retention_days
    }
  }
}

# Create directory structure for organized state files
resource "aws_s3_object" "state_directories" {
  for_each = toset(var.state_directories)

  bucket       = aws_s3_bucket.terraform_state.id
  key          = "${each.value}/"
  content_type = "application/x-directory"
}

# Create README in the bucket
resource "aws_s3_object" "readme" {
  bucket       = aws_s3_bucket.terraform_state.id
  key          = "README.md"
  content_type = "text/markdown"
  content      = <<-EOT
    # Terraform State Bucket

    This bucket stores Terraform state files for managing Scality infrastructure.

    ## Directory Structure

    ${join("\n", [for dir in var.state_directories : "- `${dir}/` - ${lookup(var.directory_descriptions, dir, "State files")}}"])}

    ## Usage

    Configure your Terraform backend:

    ```hcl
    terraform {
      backend "s3" {
        bucket   = "${var.state_bucket_name}"
        key      = "project-name/terraform.tfstate"
        region   = "us-east-1"
        endpoint = "${var.scality_endpoint}"

        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        force_path_style            = true
      }
    }
    ```

    ## Versioning

    This bucket has versioning enabled. To recover a previous state version:

    ```bash
    aws s3api list-object-versions \\
      --bucket ${var.state_bucket_name} \\
      --prefix project-name/terraform.tfstate \\
      --endpoint-url ${var.scality_endpoint}
    ```

    ## Security

    - Enable versioning: ✓ Enabled
    - Server-side encryption: ${var.enable_encryption ? "✓ Enabled" : "✗ Disabled"}
    - Access restricted to: Account administrators and CI/CD systems

    ## Maintenance

    - State file retention: ${var.old_version_retention_days} days for old versions
    - Managed by: terraform-bootstrap module
    - Created: ${timestamp()}
  EOT
}
