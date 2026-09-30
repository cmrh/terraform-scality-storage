# Delegated administration: managed stage.
#
# Everything here runs as the management user through each sub-account's
# delegated-admin role. No resource carries account_access_key /
# account_secret_key; they fall back to the aliased provider's assumed-role
# credentials.

# --- customer-a --------------------------------------------------------------

resource "scality_bucket" "customer_a" {
  provider = scality.customer_a
  bucket   = "${var.name_prefix}customer-a-data"
}

resource "scality_user" "customer_a_app" {
  provider = scality.customer_a
  username = "app"
}

# --- customer-b --------------------------------------------------------------

resource "scality_bucket" "customer_b" {
  provider = scality.customer_b
  bucket   = "${var.name_prefix}customer-b-data"
}

resource "scality_user" "customer_b_app" {
  provider = scality.customer_b
  username = "app"
}
