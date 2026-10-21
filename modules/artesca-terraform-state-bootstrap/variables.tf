variable "account_name" {
  type        = string
  default     = "terraform-state"
  description = "Dedicated ARTESCA account that owns the state bucket. Forces replacement."
}

variable "account_email" {
  type        = string
  description = "Email for the account. Forces replacement."
}

variable "bucket_name" {
  type        = string
  description = "State bucket name. Forces replacement."
}

variable "username" {
  type        = string
  default     = "terraform-state"
  description = "IAM user whose key backends use. It can read and write the state bucket only."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Bucket tags, up to 50."
}
