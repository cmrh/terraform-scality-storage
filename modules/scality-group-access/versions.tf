terraform {
  required_version = ">= 1.5.0"

  required_providers {
    scality = {
      source  = "cmrh/scality"
      version = "~> 1.1, >= 1.1.6" # TODO(#67): raise to the release with scality_iam_group_policy_attachment
    }
  }
}
