terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6"
    }
    artesca = {
      source  = "cmrh/artesca"
      version = "~> 1.2"
    }
  }
}
