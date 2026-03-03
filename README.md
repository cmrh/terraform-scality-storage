# Scality Terraform Modules

This directory contains reusable Terraform modules for Scality infrastructure.

## 🔒 Security First

**All modules support secure credential management via environment variables.**

See [Centralized Security Guide](../SECURITY.md) for complete best practices.

### Quick Security Setup

```bash
# For any module
cd <module-directory>
cp .env.example .env
vim .env  # Add your credentials
source .env
terraform apply  # Credentials automatically loaded
```

**Never commit credentials to version control!**

---

## Available Modules

### 1. s3-crr
**S3 Cross-Region Replication (CRR) Module**

Configures bidirectional Cross-Region Replication between S3-compatible buckets.

- **Location**: `s3-crr/`
- **Purpose**: Automate CRR setup between Scality RING/Zenko buckets
- **Documentation**: [s3-crr/README.md](s3-crr/README.md)
- **Quick Start**: [s3-crr/QUICKSTART.md](s3-crr/QUICKSTART.md)
- **Status**: ✅ Production Ready

**Features:**
- Multi-provider configuration (source and destination)
- Automatic IAM policy and role creation
- Bucket versioning management
- Replication configuration
- Scality Backbeat integration

**Usage:**
```hcl
module "s3_crr" {
  source = "../Modules/s3-crr"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  source_bucket_name      = "my-source-bucket"
  destination_bucket_name = "my-dest-bucket"
  # ... additional configuration
}
```

### 2. scality-account-management
**Scality Account Management Module**

Manages Scality accounts and users.

- **Location**: `scality-account-management/`
- **Purpose**: Account and user provisioning
- **Status**: ℹ️ Check module for details

### 3. terraform-state-bootstrap
**Terraform State Bootstrap Module**

Bootstraps Terraform remote state backend.

- **Location**: `terraform-state-bootstrap/`
- **Purpose**: Initial setup for Terraform state management
- **Status**: ℹ️ Check module for details

## Module Organization

Each module follows this structure:

```
module-name/
├── README.md              # Module documentation
├── variables.tf           # Input variables
├── outputs.tf            # Output values
├── main.tf (or *.tf)     # Resource definitions
├── versions.tf           # Terraform/provider versions
└── examples/             # Usage examples
    └── basic/
        ├── main.tf
        ├── variables.tf
        └── README.md
```

## Using Modules

### Local Path Reference

From a project in the same repository:

```hcl
module "my_module" {
  source = "../Modules/s3-crr"
  # ... configuration
}
```

### Relative Path from Root

If your project is in `/home/cyrus/Documents/Development/Scality/Projects/my-project/`:

```hcl
module "s3_crr" {
  source = "../../Terraform/Modules/s3-crr"
  # ... configuration
}
```

### Absolute Path (Not Recommended)

```hcl
module "s3_crr" {
  source = "/home/cyrus/Documents/Development/Scality/Terraform/Modules/s3-crr"
  # ... configuration
}
```

### Git Repository (Future)

Once modules are in a Git repository:

```hcl
module "s3_crr" {
  source = "git::https://github.com/your-org/scality-terraform-modules.git//s3-crr?ref=v1.0.0"
  # ... configuration
}
```

## Best Practices

### 1. Version Control
- Keep modules in version control (Git)
- Use semantic versioning (v1.0.0, v1.1.0, v2.0.0)
- Tag stable releases

### 2. Documentation
- Each module must have a README.md
- Include usage examples
- Document all variables and outputs
- Provide troubleshooting guides

### 3. Testing
- Test modules independently
- Provide working examples
- Document test procedures
- Validate before production use

### 4. Module Design
- Keep modules focused (single responsibility)
- Make modules reusable
- Use sensible defaults
- Validate inputs where possible
- Provide comprehensive outputs

### 5. Dependencies
- Clearly document required providers
- Specify minimum versions
- Document external dependencies

## Development Workflow

### Creating a New Module

1. **Create module directory**:
   ```bash
   mkdir -p /home/cyrus/Documents/Development/Scality/Terraform/Modules/new-module
   cd /home/cyrus/Documents/Development/Scality/Terraform/Modules/new-module
   ```

2. **Create base files**:
   ```bash
   touch README.md versions.tf variables.tf outputs.tf main.tf
   mkdir -p examples/basic
   ```

3. **Implement module**:
   - Define resources in `.tf` files
   - Document in README.md
   - Create working example

4. **Test module**:
   ```bash
   cd examples/basic
   terraform init
   terraform plan
   terraform apply
   ```

5. **Document and commit**:
   - Update main Modules README (this file)
   - Commit to version control
   - Tag if releasing a version

### Updating an Existing Module

1. **Make changes**:
   - Update `.tf` files
   - Update documentation
   - Update examples if needed

2. **Test changes**:
   ```bash
   cd examples/basic
   terraform init -upgrade
   terraform plan
   ```

3. **Version and release**:
   - Update version in documentation
   - Commit changes
   - Tag new version

## Module Registry (Future)

Consider publishing modules to:
- **Terraform Registry**: Public modules
- **Private Registry**: Internal modules
- **Artifactory/Nexus**: Enterprise artifact storage

## Directory Structure

```
Terraform/
├── Modules/                    # This directory
│   ├── README.md              # This file
│   ├── s3-crr/               # S3 CRR module
│   ├── scality-account-management/
│   └── terraform-state-bootstrap/
│
├── Environments/              # Environment-specific configs
│   ├── dev/
│   ├── staging/
│   └── production/
│
└── Projects/                  # Specific projects using modules
    └── my-project/
```

## Contributing

When contributing new modules:

1. Follow the standard module structure
2. Include comprehensive documentation
3. Provide working examples
4. Add tests where possible
5. Update this README with module details
6. Submit for review before merging

## Support

For module-specific issues:
- Check the module's README.md
- Review examples in `examples/` directory
- Check TESTING.md if available

For general Terraform questions:
- [Terraform Documentation](https://www.terraform.io/docs)
- [Terraform Registry](https://registry.terraform.io/)

For Scality-specific questions:
- [Scality Documentation](https://documentation.scality.com/)
- Internal Scality support channels

## Quick Reference

| Module | Purpose | Status | Docs |
|--------|---------|--------|------|
| s3-crr | S3 Cross-Region Replication | ✅ Ready | [README](s3-crr/README.md) |
| scality-account-management | Account Management | ℹ️ TBD | Check module |
| terraform-state-bootstrap | State Backend Setup | ℹ️ TBD | Check module |

## Recent Updates

- **2026-01-13**: Added `s3-crr` module for S3 Cross-Region Replication
  - Migrated from bash script implementation
  - Full documentation and examples included
  - Production ready

---

**Location**: `/home/cyrus/Documents/Development/Scality/Terraform/Modules/`
**Maintainer**: Infrastructure Team
**Last Updated**: 2026-01-13
