terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source = "cmrh/scality"
      # Tested on 1.1.5; earlier 1.1.x have bugs this module hits.
      version = "~> 1.1, >= 1.1.5"
    }
  }
}
