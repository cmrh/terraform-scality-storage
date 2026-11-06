terraform {
  required_version = ">= 1.5.0"

  required_providers {
    artesca = {
      source = "cmrh/artesca"
      # 1.2.1 fixes in-place updates of CRR locations.
      version = ">= 1.2.1, < 2.0.0"
    }
  }
}
