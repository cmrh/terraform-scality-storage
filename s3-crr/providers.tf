terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
      configuration_aliases = [
        aws.source,
        aws.destination
      ]
    }
  }
}

# Note: Providers are configured in the module invocation
# This allows the caller to configure custom endpoints for Scality/Zenko
