resource "artesca_group" "this" {
  account_name = var.account_name
  name         = var.group_name
}

resource "artesca_policy" "this" {
  for_each = var.policies

  account_name    = var.account_name
  name            = each.key
  policy_document = each.value
}

# Policies created here are attached by resource reference, never by a literal
# ARN, so destroy detaches them before deleting the group or the policy.
resource "artesca_group_policy_attachment" "created" {
  for_each = var.policies

  account_name = var.account_name
  group_name   = artesca_group.this.name
  policy_arn   = artesca_policy.this[each.key].arn
}

resource "artesca_group_policy_attachment" "existing" {
  for_each = var.policy_arns

  account_name = var.account_name
  group_name   = artesca_group.this.name
  policy_arn   = each.value
}

# One membership per user. Users added to the group outside this module are
# left alone.
resource "artesca_group_membership" "this" {
  for_each = var.members

  account_name = var.account_name
  group_name   = artesca_group.this.name
  username     = each.value
}
