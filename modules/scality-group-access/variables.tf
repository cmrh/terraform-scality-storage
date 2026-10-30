variable "account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of an account principal authorized to manage IAM groups and policies — typically the operator user from the account-operator module."
}

variable "account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key paired with account_access_key."
}

variable "group_name" {
  type        = string
  description = "IAM group name. Forces replacement."
}

variable "policies" {
  type        = map(string)
  default     = {}
  description = "Managed policies to create and attach to the group: policy name => JSON policy document. Construct documents with jsonencode(...) or file(...). Document updates apply in-place; renaming a policy replaces it."
}

variable "policy_arns" {
  type        = map(string)
  default     = {}
  description = "Existing managed policies, managed outside this module, to attach to the group: any static key => policy ARN. A map rather than a list so an ARN created in the same apply still works (for_each keys must be known at plan time)."
}

variable "members" {
  type        = set(string)
  default     = null
  description = "Usernames that belong to the group. Authoritative: users not listed are removed, so [] empties the group. null (default) leaves membership unmanaged."
}
