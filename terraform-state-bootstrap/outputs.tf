output "bucket_name" {
  description = "Name of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.bucket
}

output "bucket_arn" {
  description = "ARN of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "bucket_region" {
  description = "Region of the Terraform state bucket"
  value       = aws_s3_bucket.terraform_state.region
}

output "versioning_enabled" {
  description = "Whether versioning is enabled on the state bucket"
  value       = aws_s3_bucket_versioning.terraform_state.versioning_configuration[0].status == "Enabled"
}

output "backend_config" {
  description = "Backend configuration block to copy into your Terraform projects"
  value = <<-EOT
    terraform {
      backend "s3" {
        bucket   = "${aws_s3_bucket.terraform_state.bucket}"
        key      = "PROJECT_NAME/terraform.tfstate"
        region   = "us-east-1"
        endpoint = "${var.scality_endpoint}"

        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        force_path_style            = true
      }
    }
  EOT
}

output "backend_config_file" {
  description = "Backend configuration as HCL for -backend-config file"
  value = <<-EOT
    bucket   = "${aws_s3_bucket.terraform_state.bucket}"
    key      = "PROJECT_NAME/terraform.tfstate"
    region   = "us-east-1"
    endpoint = "${var.scality_endpoint}"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    force_path_style            = true
  EOT
}

output "aws_cli_example" {
  description = "Example AWS CLI command to list state files"
  value       = "aws s3 ls s3://${aws_s3_bucket.terraform_state.bucket}/ --endpoint-url ${var.scality_endpoint}"
}

output "next_steps" {
  description = "Instructions for next steps"
  value = <<-EOT
    ═══════════════════════════════════════════════════════════════════════════
    Terraform State Bucket Created Successfully!
    ═══════════════════════════════════════════════════════════════════════════

    Bucket Name: ${aws_s3_bucket.terraform_state.bucket}
    Endpoint:    ${var.scality_endpoint}
    Versioning:  ${aws_s3_bucket_versioning.terraform_state.versioning_configuration[0].status}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    STEP 1: Copy Backend Configuration
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    Add this to your Terraform projects (replace PROJECT_NAME with your project):

    terraform {
      backend "s3" {
        bucket   = "${aws_s3_bucket.terraform_state.bucket}"
        key      = "PROJECT_NAME/terraform.tfstate"
        region   = "us-east-1"
        endpoint = "${var.scality_endpoint}"

        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        force_path_style            = true
      }
    }

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    STEP 2: Initialize Backend in Your Projects
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    cd /path/to/your/terraform/project
    terraform init

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    STEP 3: Migrate Bootstrap State to S3 (Optional)
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    1. Uncomment the backend configuration in this module's main.tf
    2. Run: terraform init -migrate-state
    3. Confirm migration when prompted

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Available State Directories
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ${join("\n    ", [for dir in var.state_directories : "• ${dir}/"])}

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    Useful Commands
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    # List state files
    aws s3 ls s3://${aws_s3_bucket.terraform_state.bucket}/ --endpoint-url ${var.scality_endpoint}

    # List state file versions
    aws s3api list-object-versions \\
      --bucket ${aws_s3_bucket.terraform_state.bucket} \\
      --prefix PROJECT_NAME/terraform.tfstate \\
      --endpoint-url ${var.scality_endpoint}

    # Download state file
    aws s3 cp s3://${aws_s3_bucket.terraform_state.bucket}/PROJECT_NAME/terraform.tfstate . \\
      --endpoint-url ${var.scality_endpoint}

    ═══════════════════════════════════════════════════════════════════════════
  EOT
}
