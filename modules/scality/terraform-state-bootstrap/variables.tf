variable "account_name" {
  type        = string
  description = "Dedicated Scality account that will own the state bucket. 1-128 chars, alphanumeric and hyphens. Forces account replacement if changed."
  default     = "terraform-state"
}

variable "account_email" {
  type        = string
  description = "Email address registered against the dedicated state account. Forces account replacement if changed."
}

variable "account_attributes" {
  type        = map(string)
  description = "Custom attributes (key-value metadata) applied to the dedicated state account. Same purpose as tags for buckets. Max 10 attributes per account."
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
