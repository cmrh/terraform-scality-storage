terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source                = "scality/scality"
      version               = "~> 0.4"
      configuration_aliases = [scality.source, scality.dest]
    }
  }
}
