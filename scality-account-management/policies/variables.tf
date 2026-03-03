variable "policies" {
  description = "Map of IAM policies to create"
  type = map(object({
    description     = string
    policy_document = string
    path            = optional(string, "/")
  }))
  default = {}
}
