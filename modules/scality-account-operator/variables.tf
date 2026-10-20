variable "account_access_key" {
  type        = string
  sensitive   = true
  description = "Account-root access key (typically the output of scality-account-management). Used only to bootstrap the operator user — after this module applies, switch downstream wrapper modules to consume the operator's credentials and reserve the account-root keys for break-glass scenarios. Forces replacement."
}

variable "account_secret_key" {
  type        = string
  sensitive   = true
  description = "Account-root secret key paired with account_access_key. Forces replacement."
}

variable "operator_username" {
  type        = string
  default     = "operator"
  description = "Username for the operator user. Forces replacement."
}

variable "policy_name" {
  type        = string
  default     = null
  description = "Inline policy name. Defaults to \"<operator_username>-policy\" when null."
}
