# Get source account ID via STS
data "aws_caller_identity" "source" {
  provider = aws.source
}

# Get destination account ID via STS
data "aws_caller_identity" "destination" {
  provider = aws.destination
}

# Locals to handle account IDs (use provided or detected)
locals {
  source_account_id      = var.source_account_id != "" ? var.source_account_id : data.aws_caller_identity.source.account_id
  destination_account_id = var.destination_account_id != "" ? var.destination_account_id : data.aws_caller_identity.destination.account_id

  # Generate unique names with timestamp if not provided
  timestamp   = formatdate("YYYYMMDDhhmmss", timestamp())
  policy_name = var.policy_name != "" ? var.policy_name : "crr-policy-${local.timestamp}"
  role_name   = var.role_name != "" ? var.role_name : "crr-trust-role-${local.timestamp}"
}
