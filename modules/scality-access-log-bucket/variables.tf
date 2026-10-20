variable "account_access_key" {
  type        = string
  sensitive   = true
  description = "Access key of a principal in the account that owns the log bucket and the source buckets, e.g. the account-operator user."
}

variable "account_secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key paired with account_access_key."
}

variable "bucket_name" {
  type        = string
  description = "Name of the log bucket. Forces replacement."
}

variable "retention_days" {
  type        = number
  default     = 90
  description = "Days after which log objects are deleted."

  validation {
    condition     = var.retention_days >= 1 && floor(var.retention_days) == var.retention_days
    error_message = "retention_days must be a whole number of at least 1."
  }
}

variable "logged_buckets" {
  type        = map(string)
  default     = {}
  description = "Source buckets to log, as bucket name => key prefix in the log bucket (e.g. { \"app-data\" = \"app-data/\" }). The source buckets must be in the same account."
}

variable "log_delivery_principal" {
  type        = string
  default     = "arn:aws:iam::000000000000:user/scality-internal/service-access-logging-user"
  description = "The cluster's internal access-logging service user, granted s3:PutObject on the log bucket. Override only if your cluster uses a non-default service user."
}

variable "sse_algorithm" {
  type        = string
  default     = "AES256"
  description = "Server-side encryption for the log bucket: \"AES256\" or \"aws:kms\". Set null to disable."

  validation {
    condition     = var.sse_algorithm == null || contains(["AES256", "aws:kms"], coalesce(var.sse_algorithm, "AES256"))
    error_message = "sse_algorithm must be \"AES256\", \"aws:kms\" or null."
  }
}

variable "kms_master_key_id" {
  type        = string
  default     = null
  description = "KMS key ID. Required when sse_algorithm = \"aws:kms\", ignored otherwise."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the log bucket."
}
