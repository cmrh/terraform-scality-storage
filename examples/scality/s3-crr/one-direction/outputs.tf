# ============================================================
# Bucket and role references
# ============================================================

output "source_bucket_name" {
  description = "Source-cluster bucket name."
  value       = module.source_bucket.bucket_name
}

output "dest_bucket_name" {
  description = "Destination-cluster bucket name."
  value       = module.dest_bucket.bucket_name
}

output "source_role_arn" {
  description = "Source-cluster IAM role (backbeat assumes this to perform replication)."
  value       = module.crr.source_role_arn
}

output "dest_role_arn" {
  description = "Destination-cluster IAM role."
  value       = module.crr.dest_role_arn
}

# ============================================================
# Operator credentials — full IAM + S3 on each account.
# Use for day-to-day administration; reserve account-root for
# break-glass.
# ============================================================

output "source_operator_username" {
  description = "Operator username on the source-cluster account."
  value       = module.source_operator.username
}

output "source_operator_access_key" {
  description = "Source-cluster operator access key (full S3 + IAM)."
  value       = module.source_operator.access_key
  sensitive   = true
}

output "source_operator_secret_key" {
  value     = module.source_operator.secret_key
  sensitive = true
}

output "dest_operator_username" {
  description = "Operator username on the destination-cluster account."
  value       = module.dest_operator.username
}

output "dest_operator_access_key" {
  description = "Destination-cluster operator access key (full S3 + IAM)."
  value       = module.dest_operator.access_key
  sensitive   = true
}

output "dest_operator_secret_key" {
  value     = module.dest_operator.secret_key
  sensitive = true
}

# ============================================================
# Verification users — scoped to a single bucket each.
# ============================================================

output "source_writer_access_key" {
  description = "Source-side writer — read-write on the source bucket only."
  value       = module.source_writer.access_key
  sensitive   = true
}

output "source_writer_secret_key" {
  value     = module.source_writer.secret_key
  sensitive = true
}

output "dest_reader_access_key" {
  description = "Destination-side reader — read-only on the dest bucket. Use to confirm replicated objects appear."
  value       = module.dest_reader.access_key
  sensitive   = true
}

output "dest_reader_secret_key" {
  value     = module.dest_reader.secret_key
  sensitive = true
}
