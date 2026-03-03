variable "groups" {
  description = "Map of IAM groups to create"
  type = map(object({
    path     = optional(string, "/")
    policies = optional(list(string), [])
  }))
  default = {}
}
