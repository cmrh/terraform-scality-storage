terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source = "cmrh/scality"
      # Cross-account trust + the provider assume_role block that consumes
      # this role were validated on 1.1.0.
      version = "~> 1.1"
    }
  }
}
