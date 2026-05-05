module "user" {
  source = "../application-identity"

  account_access_key = var.account_access_key
  account_secret_key = var.account_secret_key

  username        = var.operator_username
  policy_name     = var.policy_name
  policy_document = file("${path.module}/policy.json")
}
