variable "account_name" {
  type        = string
  description = "Account that owns the group and its policies. Forces replacement."
}

variable "group_name" {
  type        = string
  description = "IAM group name. Forces replacement."
}

variable "policies" {
  type        = map(string)
  default     = {}
  description = "Managed policies to create and attach to the group: policy name => JSON policy document. Construct documents with jsonencode(...) or file(...). Document updates apply in place; renaming a policy replaces it."
}

variable "policy_arns" {
  type        = map(string)
  default     = {}
  description = "Existing managed policies, managed outside this module, to attach to the group: any static key => policy ARN. A map rather than a list so an ARN created in the same apply still works (for_each keys must be known at plan time)."
}

variable "members" {
  type        = set(string)
  default     = []
  description = "Usernames to add to the group, one membership each. Users added outside this module are left in the group."
}
