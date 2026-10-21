variable "account_name" {
  type        = string
  description = "Name of the ARTESCA account to create. 1-128 characters: letters, numbers and hyphens. Forces replacement."

  validation {
    condition     = can(regex("^[A-Za-z0-9-]{1,128}$", var.account_name))
    error_message = "account_name must be 1-128 characters: letters, numbers and hyphens."
  }
}

variable "account_email" {
  type        = string
  description = "Email address for the account. Forces replacement."
}
