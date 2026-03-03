variable "console_endpoint" {
  description = "Scality Console API endpoint for account creation"
  type        = string
  default     = "http://10.164.169.247:8080"
}

variable "console_username" {
  description = "Console API admin username"
  type        = string
  sensitive   = true
}

variable "console_password" {
  description = "Console API admin password"
  type        = string
  sensitive   = true
}

variable "scality_endpoint" {
  description = "Scality S3/IAM endpoint for IAM operations"
  type        = string
  default     = "http://10.164.169.247"
}
