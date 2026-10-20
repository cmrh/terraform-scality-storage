output "account_name" {
  value       = artesca_account.this.name
  description = "ARTESCA account name."
}

output "account_id" {
  value       = artesca_account.this.id
  description = "ARTESCA account ID."
}

output "bucket_name" {
  value       = artesca_bucket.this.name
  description = "Source bucket on ARTESCA."
}

output "location_name" {
  value       = artesca_location.ring.name
  description = "RING location name."
}

output "replication_rule_id" {
  value       = artesca_bucket_workflow_replication.this.rule_id
  description = "Replication rule ID (the workflow ID in the ARTESCA UI)."
}

output "user_access_keys" {
  value = {
    for u, k in artesca_user_access_key.this : u => {
      access_key = k.access_key_id
      secret_key = k.secret_access_key
    }
  }
  sensitive   = true
  description = "Access keys per user."
}
