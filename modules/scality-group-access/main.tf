resource "scality_group" "this" {
  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  group_name         = var.group_name
}

resource "scality_iam_policy" "this" {
  for_each = var.policies

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  policy_name        = each.key
  policy_document    = each.value
}

# Policies created here are attached by resource reference, never by a literal
# ARN, so destroy detaches them before deleting the group or the policy
# (otherwise the deletes race and fail with DeleteConflict).
resource "scality_iam_group_policy_attachment" "created" {
  for_each = var.policies

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  group_name         = scality_group.this.group_name
  policy_arn         = scality_iam_policy.this[each.key].arn
}

resource "scality_iam_group_policy_attachment" "existing" {
  for_each = var.policy_arns

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  group_name         = scality_group.this.group_name
  policy_arn         = each.value
}

# Authoritative: users not listed are removed from the group. Skipped when
# members is null, so membership can be managed elsewhere.
resource "scality_group_membership" "this" {
  count = var.members == null ? 0 : 1

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key
  group_name         = scality_group.this.group_name
  users              = var.members
}
