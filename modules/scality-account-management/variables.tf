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

variable "account_credentials" {
  type = object({
    access_key = string
    secret_key = string
  })
  default     = null
  sensitive   = true
  description = "An existing access key of the account, for adopting an account created outside this module (import it into scality_account.this[0]). Requires console_login = false. The module creates a Terraform-owned key from it and outputs that key. The key passed here must stay valid and set: the module uses it to manage the new key."
}
