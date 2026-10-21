variable "name" {
  type        = string
  description = "Location name: at least 3 characters, lowercase letters, numbers and hyphens, starting with a letter. Locations are instance-wide. Forces replacement."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,}$", var.name))
    error_message = "name must be at least 3 characters: lowercase letters, numbers and hyphens, starting with a letter."
  }
}

variable "type" {
  type        = string
  default     = "ring-s3"
  description = "Backend type: \"ring-s3\" (Scality RING S3) or \"versity-tape\" (Versity tape archive, a cold location; the endpoint must be https://). Forces replacement."

  validation {
    condition     = contains(["ring-s3", "versity-tape"], var.type)
    error_message = "type must be \"ring-s3\" or \"versity-tape\"."
  }
}

variable "endpoint" {
  type        = string
  description = "S3 endpoint URL of the backend, as ARTESCA reaches it. Must be https:// for versity-tape."
}

variable "bucket_name" {
  type        = string
  description = "Target bucket on the backend."
}

variable "access_key" {
  type        = string
  sensitive   = true
  description = "Backend access key. See README for the permissions each use needs."
}

variable "secret_key" {
  type        = string
  sensitive   = true
  description = "Secret key matching access_key."
}

variable "bucket_match" {
  type        = bool
  default     = true
  description = "true (default): objects keep their keys at the root of the target bucket. false: they go under a prefix named after the source bucket. Forces replacement."
}

variable "size_limit_gb" {
  type        = number
  default     = null
  description = "Storage size limit in gigabytes. Null (default) sets no limit."
}

variable "endpoint_hostname" {
  type        = string
  default     = null
  description = "Hostname for an ARTESCA S3 endpoint that serves this location. Null (default) creates no endpoint. Forces replacement."
}
