variable "scality_endpoint" {
  description = "Scality S3/IAM endpoint URL"
  type        = string
  default     = "http://10.164.169.247"
}

variable "use_https" {
  description = "Use HTTPS for Scality endpoint"
  type        = bool
  default     = false
}

variable "access_key" {
  description = "Account admin access key (optional - uses AWS_ACCESS_KEY_ID env var if not provided)"
  type        = string
  default     = null
  sensitive   = true
}

variable "secret_key" {
  description = "Account admin secret key (optional - uses AWS_SECRET_ACCESS_KEY env var if not provided)"
  type        = string
  default     = null
  sensitive   = true
}
