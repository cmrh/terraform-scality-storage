# Security Best Practices

This document outlines security best practices for using the S3 CRR Terraform module.

## Credential Management

### ⚠️ Never Commit Credentials to Version Control

**DO NOT:**
- ❌ Hard-code credentials in `.tf` files
- ❌ Commit `terraform.tfvars` with credentials to Git
- ❌ Store credentials in plain text files in your repository
- ❌ Share credentials via email, Slack, or other communication channels

**DO:**
- ✅ Use environment variables
- ✅ Use credential management systems (Vault, AWS Secrets Manager)
- ✅ Add `*.tfvars` to `.gitignore`
- ✅ Use separate credentials for dev/staging/prod
- ✅ Rotate credentials regularly

---

## Recommended: Use Environment Variables

The module supports environment variables for credentials, which is the **most secure approach** for local development and CI/CD pipelines.

### Environment Variable Names

The module recognizes these environment variables:

```bash
# Source credentials
export SCALITY_SOURCE_ACCESS_KEY="your-source-access-key"
export SCALITY_SOURCE_SECRET_KEY="your-source-secret-key"

# Destination credentials
export SCALITY_DESTINATION_ACCESS_KEY="your-destination-access-key"
export SCALITY_DESTINATION_SECRET_KEY="your-destination-secret-key"
```

### Usage with Environment Variables

**Step 1: Set Environment Variables**

```bash
# Option 1: Export in your shell session
export SCALITY_SOURCE_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE"
export SCALITY_SOURCE_SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export SCALITY_DESTINATION_ACCESS_KEY="AKIAI44QH8DHBEXAMPLE"
export SCALITY_DESTINATION_SECRET_KEY="je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY"

# Option 2: Use a .env file (add to .gitignore!)
# Create .env file:
cat > .env << 'EOF'
export SCALITY_SOURCE_ACCESS_KEY="AKIAIOSFODNN7EXAMPLE"
export SCALITY_SOURCE_SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export SCALITY_DESTINATION_ACCESS_KEY="AKIAI44QH8DHBEXAMPLE"
export SCALITY_DESTINATION_SECRET_KEY="je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY"
EOF

# Source the file:
source .env

# IMPORTANT: Add .env to .gitignore
echo ".env" >> .gitignore
```

**Step 2: Configure Module WITHOUT Credentials in Code**

```hcl
# main.tf - NO credentials in this file!
module "s3_crr" {
  source = "../../Terraform/Modules/s3-crr"

  providers = {
    aws.source      = aws.source
    aws.destination = aws.destination
  }

  # Bucket configuration
  source_bucket_name      = "my-source-bucket"
  destination_bucket_name = "my-dest-bucket"

  # Endpoints
  source_endpoint      = "https://source.scality.local"
  destination_endpoint = "https://destination.scality.local"

  # Credentials are read from environment variables automatically
  # No need to specify source_access_key, source_secret_key, etc.

  # Other configuration
  create_source_bucket      = true
  create_destination_bucket = true
}
```

**Step 3: Provider Configuration**

Terraform will automatically use the environment variables via the module:

```hcl
provider "aws" {
  alias      = "source"
  region     = "us-east-1"

  # Credentials come from module variables, which read from environment
  access_key = var.source_access_key  # Reads SCALITY_SOURCE_ACCESS_KEY
  secret_key = var.source_secret_key  # Reads SCALITY_SOURCE_SECRET_KEY

  endpoints {
    s3  = "https://source.scality.local"
    iam = "https://source.scality.local"
    sts = "https://source.scality.local"
  }

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style          = true
}
```

---

## Alternative: Use Terraform Variables (Less Secure)

If you must use Terraform variables, follow these practices:

### Method 1: Interactive Input (Most Secure for Manual Runs)

Don't provide credentials in files at all. Terraform will prompt you:

```hcl
# variables.tf
variable "source_access_key" {
  description = "Source access key"
  type        = string
  sensitive   = true
}

# Run terraform - it will prompt for values
terraform plan
# Enter a value for source_access_key: [you type it securely]
```

### Method 2: Separate tfvars File (Never Commit!)

```bash
# Create terraform.tfvars (MUST be in .gitignore)
cat > terraform.tfvars << 'EOF'
source_access_key      = "AKIAIOSFODNN7EXAMPLE"
source_secret_key      = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
destination_access_key = "AKIAI44QH8DHBEXAMPLE"
destination_secret_key = "je7MtGbClwBF/2Zp9Utk/h3yCo8nvbEXAMPLEKEY"
EOF

# Add to .gitignore immediately!
echo "terraform.tfvars" >> .gitignore
echo "*.tfvars" >> .gitignore
echo "!terraform.tfvars.example" >> .gitignore
```

### Method 3: Command Line (Avoid - Visible in History)

**⚠️ NOT RECOMMENDED** - Credentials appear in shell history:

```bash
terraform apply \
  -var="source_access_key=AKIAIOSFODNN7EXAMPLE" \
  -var="source_secret_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

---

## Advanced: Use Credential Management Systems

For production environments, integrate with enterprise credential management:

### HashiCorp Vault

```hcl
# Retrieve credentials from Vault
data "vault_generic_secret" "scality_source" {
  path = "secret/scality/source"
}

data "vault_generic_secret" "scality_destination" {
  path = "secret/scality/destination"
}

module "s3_crr" {
  source = "../../Terraform/Modules/s3-crr"

  source_access_key      = data.vault_generic_secret.scality_source.data["access_key"]
  source_secret_key      = data.vault_generic_secret.scality_source.data["secret_key"]
  destination_access_key = data.vault_generic_secret.scality_destination.data["access_key"]
  destination_secret_key = data.vault_generic_secret.scality_destination.data["secret_key"]

  # ... other configuration
}
```

### AWS Secrets Manager

```hcl
data "aws_secretsmanager_secret_version" "scality_source" {
  secret_id = "scality/source/credentials"
}

locals {
  source_creds = jsondecode(data.aws_secretsmanager_secret_version.scality_source.secret_string)
}

module "s3_crr" {
  source = "../../Terraform/Modules/s3-crr"

  source_access_key = local.source_creds.access_key
  source_secret_key = local.source_creds.secret_key

  # ... other configuration
}
```

### Azure Key Vault

```hcl
data "azurerm_key_vault_secret" "scality_source_access" {
  name         = "scality-source-access-key"
  key_vault_id = azurerm_key_vault.main.id
}

data "azurerm_key_vault_secret" "scality_source_secret" {
  name         = "scality-source-secret-key"
  key_vault_id = azurerm_key_vault.main.id
}

module "s3_crr" {
  source = "../../Terraform/Modules/s3-crr"

  source_access_key = data.azurerm_key_vault_secret.scality_source_access.value
  source_secret_key = data.azurerm_key_vault_secret.scality_source_secret.value

  # ... other configuration
}
```

---

## CI/CD Pipeline Security

### GitHub Actions

```yaml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2

      - name: Terraform Init
        run: terraform init

      - name: Terraform Apply
        env:
          # Set from GitHub Secrets
          SCALITY_SOURCE_ACCESS_KEY: ${{ secrets.SCALITY_SOURCE_ACCESS_KEY }}
          SCALITY_SOURCE_SECRET_KEY: ${{ secrets.SCALITY_SOURCE_SECRET_KEY }}
          SCALITY_DESTINATION_ACCESS_KEY: ${{ secrets.SCALITY_DESTINATION_ACCESS_KEY }}
          SCALITY_DESTINATION_SECRET_KEY: ${{ secrets.SCALITY_DESTINATION_SECRET_KEY }}
        run: terraform apply -auto-approve
```

### GitLab CI

```yaml
deploy:
  stage: deploy
  script:
    - terraform init
    - terraform apply -auto-approve
  variables:
    # Use GitLab CI/CD Variables (masked)
    SCALITY_SOURCE_ACCESS_KEY: $SOURCE_ACCESS_KEY
    SCALITY_SOURCE_SECRET_KEY: $SOURCE_SECRET_KEY
    SCALITY_DESTINATION_ACCESS_KEY: $DESTINATION_ACCESS_KEY
    SCALITY_DESTINATION_SECRET_KEY: $DESTINATION_SECRET_KEY
```

### Jenkins

```groovy
pipeline {
    agent any

    environment {
        // Use Jenkins Credentials binding
        SCALITY_CREDS = credentials('scality-credentials-id')
    }

    stages {
        stage('Deploy') {
            steps {
                withCredentials([
                    string(credentialsId: 'scality-source-access', variable: 'SCALITY_SOURCE_ACCESS_KEY'),
                    string(credentialsId: 'scality-source-secret', variable: 'SCALITY_SOURCE_SECRET_KEY'),
                    string(credentialsId: 'scality-dest-access', variable: 'SCALITY_DESTINATION_ACCESS_KEY'),
                    string(credentialsId: 'scality-dest-secret', variable: 'SCALITY_DESTINATION_SECRET_KEY')
                ]) {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}
```

---

## Credential Rotation

Best practice: Rotate credentials regularly.

### Rotation Procedure

1. **Generate new credentials** in Scality
2. **Update environment variables** or secret store
3. **Test new credentials** in non-production first
4. **Update production** during maintenance window
5. **Revoke old credentials** after successful migration

### Automation Example

```bash
#!/bin/bash
# rotate-credentials.sh

# Generate new credentials (example - adjust for your Scality API)
NEW_SOURCE_ACCESS=$(generate_new_scality_access_key --account source)
NEW_SOURCE_SECRET=$(get_secret_for_access_key $NEW_SOURCE_ACCESS)

# Update in secret store
vault kv put secret/scality/source \
  access_key="$NEW_SOURCE_ACCESS" \
  secret_key="$NEW_SOURCE_SECRET"

# Test with new credentials
export SCALITY_SOURCE_ACCESS_KEY="$NEW_SOURCE_ACCESS"
export SCALITY_SOURCE_SECRET_KEY="$NEW_SOURCE_SECRET"

terraform plan

# If successful, revoke old credentials
revoke_scality_access_key --key "$OLD_SOURCE_ACCESS"
```

---

## State File Security

Terraform state files contain sensitive information!

### Secure State Storage

**Remote Backend with Encryption:**

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "scality/crr/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

**Terraform Cloud (Encrypted by default):**

```hcl
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "scality-crr-production"
    }
  }
}
```

### State File Best Practices

- ✅ Use remote backend with encryption
- ✅ Enable versioning on state storage
- ✅ Restrict access to state files (IAM/RBAC)
- ✅ Enable state locking (prevents concurrent modifications)
- ❌ Never commit state files to version control
- ❌ Never share state files via email/Slack

---

## Security Checklist

Before deploying to production:

- [ ] Credentials are NOT hard-coded in `.tf` files
- [ ] `.tfvars` files with secrets are in `.gitignore`
- [ ] Using environment variables or secret management system
- [ ] Remote state backend is configured with encryption
- [ ] State file access is restricted (IAM/RBAC)
- [ ] Credentials rotate on a schedule (quarterly minimum)
- [ ] CI/CD uses masked/encrypted secrets
- [ ] Separate credentials for dev/staging/prod
- [ ] Audit logging enabled for credential access
- [ ] Team trained on credential management practices

---

## Audit and Compliance

### Logging

Enable audit logging for credential usage:

```hcl
# Example: CloudWatch logging for Terraform operations
resource "aws_cloudwatch_log_group" "terraform_audit" {
  name              = "/terraform/scality-crr"
  retention_in_days = 90

  tags = {
    Purpose = "Audit"
    Compliance = "SOC2"
  }
}
```

### Compliance Requirements

Different compliance frameworks have different requirements:

| Framework | Requirement | Implementation |
|-----------|-------------|----------------|
| SOC 2 | Encrypted credential storage | Use Vault/Secrets Manager |
| PCI-DSS | Credential rotation | Quarterly rotation minimum |
| HIPAA | Audit logging | Enable CloudWatch/Splunk |
| ISO 27001 | Access control | RBAC on secret stores |

---

## Incident Response

If credentials are compromised:

1. **Immediately revoke** compromised credentials in Scality
2. **Generate new credentials** for affected services
3. **Update** all systems using compromised credentials
4. **Audit** access logs to determine scope of exposure
5. **Document** incident and response actions
6. **Review** security practices to prevent recurrence

---

## Additional Resources

- [Terraform Security Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/part1.html)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/)
- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

## Support

For security concerns or questions:
- Internal: [Security Team Contact]
- Documentation: [This file]
- Emergency: [Security Incident Response Procedure]
