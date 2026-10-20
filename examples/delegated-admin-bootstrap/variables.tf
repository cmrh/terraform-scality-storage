variable "name_prefix" {
  type        = string
  default     = ""
  description = "Prefix for every account name. Set per run in CI (TF_VAR_name_prefix) to avoid collisions."
}

variable "sub_accounts" {
  type        = set(string)
  default     = ["customer-a", "customer-b"]
  description = "Sub-accounts to create, each with a delegated-admin role. The managed stage declares one provider alias per entry."
}

variable "delegator_username" {
  type        = string
  default     = "delegator"
  description = "Management-account user trusted by every sub-account role. After a compromise, change this name (see the delegated-admin-role README)."
}
