terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source                = "cmrh/scality"
      version               = "~> 1.2"
      configuration_aliases = [scality.source, scality.dest]
    }
  }
}
