variable "users" {
  description = "Map of IAM users to create"
  type = map(object({
    path                = optional(string, "/")
    tags                = optional(map(string), {})
    groups              = optional(list(string), [])
    policies            = optional(list(string), [])
    generate_access_key = optional(bool, true)
  }))
  default = {}
}
