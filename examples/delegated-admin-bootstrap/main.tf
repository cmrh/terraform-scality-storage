# Delegated administration: bootstrap stage.
#
# superadmin    -> management account + sub-accounts
# mgmt root     -> delegator user (sts:AssumeRole on the sub-account roles)
# sub-acct root -> delegated-admin-role in each sub-account, trusting delegator
#
# The managed stage (../managed) then uses delegator's keys to assume each
# role. It must be a separate root config: a role has to exist before a
# provider can be configured to assume it.

module "mgmt_account" {
  source = "../../modules/scality-account-management"

  account_name  = "${var.name_prefix}mgmt"
  account_email = "${var.name_prefix}mgmt@delegated-admin.example.com"
  console_login = false
}

module "sub_account" {
  source   = "../../modules/scality-account-management"
  for_each = var.sub_accounts

  account_name  = "${var.name_prefix}${each.key}"
  account_email = "${var.name_prefix}${each.key}@delegated-admin.example.com"
  console_login = false
}

module "admin_role" {
  source   = "../../modules/scality-delegated-admin-role"
  for_each = var.sub_accounts

  account_access_key = module.sub_account[each.key].access_key
  account_secret_key = module.sub_account[each.key].secret_key

  # Built as a string, not module.delegator.user_arn, so replacing the user
  # doesn't cascade into replacing every role.
  trusted_user_arn = "arn:aws:iam::${module.mgmt_account.account_id}:user/${var.delegator_username}"
}

module "delegator" {
  source = "../../modules/scality-application-identity"

  account_access_key = module.mgmt_account.access_key
  account_secret_key = module.mgmt_account.secret_key

  username    = var.delegator_username
  policy_name = "assume-sub-account-roles"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = [for r in module.admin_role : r.role_arn]
    }]
  })
}
