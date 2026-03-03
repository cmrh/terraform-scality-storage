output "summary" {
  description = "Summary of created IAM resources"
  value       = module.scality_iam.summary
}

output "users" {
  description = "Created IAM users"
  value       = module.scality_iam.users
}

output "groups" {
  description = "Created IAM groups"
  value       = module.scality_iam.groups
}

output "policies" {
  description = "Created IAM policies"
  value       = module.scality_iam.policies
}

output "user_credentials" {
  description = "User access keys (sensitive - use terraform output -json to view)"
  value       = module.scality_iam.user_access_keys
  sensitive   = true
}

output "credentials_files" {
  description = "Location of saved credential files"
  value = {
    for user in keys(module.scality_iam.user_access_keys) :
    user => "${path.module}/credentials/${user}.ini"
  }
}
