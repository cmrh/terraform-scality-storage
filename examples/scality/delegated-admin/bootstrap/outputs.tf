output "mgmt_account_id" {
  description = "Management account ID."
  value       = module.mgmt_account.account_id
}

output "role_arns" {
  description = "Delegated-admin role ARN per sub-account. Feed to the managed stage as TF_VAR_role_arns."
  value       = { for k, r in module.admin_role : k => r.role_arn }
}

output "delegator_access_key" {
  description = "Management user's access key. Feed to the managed stage as TF_VAR_delegator_access_key."
  value       = module.delegator.access_key
  sensitive   = true
}

output "delegator_secret_key" {
  description = "Management user's secret key. Feed to the managed stage as TF_VAR_delegator_secret_key."
  value       = module.delegator.secret_key
  sensitive   = true
}

# Kept for break-glass. Move them into a secret store if you have one;
# nothing in the managed stage needs them.
output "mgmt_root_keys" {
  description = "Management account root keys."
  value       = { access_key = module.mgmt_account.access_key, secret_key = module.mgmt_account.secret_key }
  sensitive   = true
}

output "sub_account_root_keys" {
  description = "Root keys per sub-account."
  value       = { for k, a in module.sub_account : k => { access_key = a.access_key, secret_key = a.secret_key } }
  sensitive   = true
}
