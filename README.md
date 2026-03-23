# Scality Terraform Modules

Reusable Terraform modules for managing Scality on-premises S3 storage infrastructure.

> **Security**: Always use environment variables for credentials. Never commit secrets to git.

## Available Modules

| Module | Description | Status |
|--------|-------------|--------|
| **[s3-crr](s3-crr/)** | Cross-Region Replication between Scality buckets |  Production |
| **[s3-bucket](s3-bucket/)** | S3 bucket creation and configuration |  Production |
| **[s3-bucket-lifecycle](s3-bucket-lifecycle/)** | S3 bucket lifecycle policies |  Production |
| **[scality-account-management](scality-account-management/)** | IAM users, groups, and policies |  Production |
| **[terraform-state-bootstrap](terraform-state-bootstrap/)** | Remote state backend setup |  Production |

## Quick Start

```bash
# Set credentials via environment variables (recommended)
export SCALITY_ENDPOINT="http://scality.example.com"
export SCALITY_ACCESS_KEY="your-access-key"
export SCALITY_SECRET_KEY="your-secret-key"

# Use a module
cd my-project
cat > main.tf <<EOF
module "bucket" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//s3-bucket"

  bucket_name = "my-bucket"
}
EOF

terraform init
terraform apply
```

## Module Usage

### From Git Repository

```hcl
module "bucket" {
  source = "git::https://github.com/scality/scality-s3-tf-modules.git//s3-bucket?ref=v1.0.0"

  bucket_name = "my-bucket"
}
```

### Local Path

```hcl
module "bucket" {
  source = "../scality-s3-tf-modules/s3-bucket"

  bucket_name = "my-bucket"
}
```

## Security Best Practices

**Always use environment variables for credentials:**

```bash
export SCALITY_ENDPOINT="http://scality.example.com"
export SCALITY_ACCESS_KEY="your-access-key"
export SCALITY_SECRET_KEY="your-secret-key"
```

**In your Terraform code:**

```hcl
provider "aws" {
  region = "us-east-1"

  endpoints {
    s3 = var.s3_endpoint  # From TF_VAR_s3_endpoint or terraform.tfvars
  }

  access_key = var.access_key  # From environment
  secret_key = var.secret_key  # From environment

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true
}
```

> **Never hardcode credentials in `.tf` files or commit them to git!**

## Module Structure

Each module follows standard Terraform conventions:

```
module-name/
├── README.md              # Documentation
├── variables.tf           # Input variables
├── outputs.tf            # Outputs
├── main.tf               # Resources
├── versions.tf           # Provider requirements
└── examples/             # Usage examples
    └── basic/
```

## Contributing

1. Include comprehensive documentation in `README.md`
2. Provide working examples in `examples/`
3. Use semantic versioning for releases
4. Test before submitting PRs

## License

Apache 2.0
