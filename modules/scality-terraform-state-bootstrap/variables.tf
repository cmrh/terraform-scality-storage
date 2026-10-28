variable "account_name" {
  type        = string
  description = "Dedicated Scality account that will own the state bucket. 1-128 chars, alphanumeric and hyphens. Forces account replacement if changed."
  default     = "terraform-state"
}

variable "account_email" {
  type        = string
  description = "Email address registered against the dedicated state account. Forces account replacement if changed."
}

variable "console_login" {
  type        = bool
  default     = true
  description = "When true (default), creates a scality_console_account with a randomly generated UI password (exposed via console_password output) — useful for admins who want to verify the state account or bucket via the Console UI. When false, creates a scality_account (headless; supports account_attributes). Defaulting to true gives parity with scality-account-management. Switching after apply is destructive."
}

variable "account_attributes" {
  type        = map(string)
  description = "Custom attributes (key-value metadata) applied to the dedicated state account. Same purpose as tags for buckets. Max 10 attributes per account. Only effective when console_login = false (scality_console_account does not accept custom attributes)."
  default = {
    managed_by = "terraform"
    purpose    = "state-file"
  }
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket that will hold Terraform/OpenTofu state files. 3-63 chars, lowercase + digits + hyphens + periods."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the state bucket."
  default = {
    managed_by = "terraform"
    purpose    = "state-file"
  }
}

variable "sse_algorithm" {
  type        = string
  description = "Server-side encryption algorithm. Use \"AES256\" (SSE-S3) for every standard deployment. \"aws:kms\" requires an external KMS configured on the cluster."
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be either \"AES256\" or \"aws:kms\"."
  }
}

variable "kms_master_key_id" {
  type        = string
  description = "KMS key ID. Required when sse_algorithm = \"aws:kms\", ignored otherwise."
  default     = null
}

variable "abort_incomplete_multipart_upload_days" {
  type        = number
  description = "Days after which incomplete multipart uploads are aborted. Frees orphaned parts left behind by interrupted writes."
  default     = 7
}

variable "noncurrent_version_expiration_days" {
  type        = number
  description = "Days after which superseded state versions are permanently deleted. Set high enough to comfortably roll back from accidental corruption."
  default     = 90
}

variable "account_credentials" {
  type = object({
    access_key = string
    secret_key = string
  })
  default     = null
  sensitive   = true
  description = "An existing access key of the account, for adopting an account created outside this module (import it into scality_account.state[0]). Requires console_login = false. The module creates a Terraform-owned key from it and uses that key. The key passed here must stay valid and set: the module uses it to manage the new key."
}
