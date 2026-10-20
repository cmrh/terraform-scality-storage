terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source = "cmrh/scality"
      # Earlier 1.1.x have bugs this module hits.
      version = "~> 1.1, >= 1.1.6"
    }
  }
}
