variable "account_name" {
  type        = string
  description = "Name of the Scality account to create. 1-128 chars, alphanumeric and hyphens. Forces replacement if changed."
}

variable "account_email" {
  type        = string
  description = "Email address registered against the account. Forces replacement if changed."
}

variable "console_login" {
  type        = bool
  default     = true
  description = "When true (default), creates a scality_console_account with a randomly generated UI password (exposed via the console_password output). When false, creates a scality_account — no UI access, but supports custom attributes and an external account ID. Switching this flag after creation is destructive: the existing account is destroyed and a new one is created."
}

variable "account_quota" {
  type        = number
  default     = null
  description = "Maximum bytes storable in this account. Leave null (default) for the server default; set 0 for unlimited. Forces replacement if changed."
}

variable "external_account_id" {
  type        = string
  default     = null
  description = "External integration ID for the account. Only effective when console_login = false (scality_console_account does not accept this field). Forces replacement if changed."
}

variable "account_attributes" {
  type        = map(string)
  default     = {}
  description = "Custom attributes (key-value metadata) for the account. Only effective when console_login = false (scality_console_account does not accept custom attributes). Max 10 attributes per account."
}
