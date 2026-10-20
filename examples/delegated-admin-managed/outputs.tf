output "buckets" {
  description = "Bucket created in each sub-account."
  value = {
    customer-a = scality_bucket.customer_a.bucket
    customer-b = scality_bucket.customer_b.bucket
  }
}

output "app_user_arns" {
  description = "App user ARN in each sub-account. Each ARN carries its sub-account's ID, which shows the resource landed in the sub-account, not the management account."
  value = {
    customer-a = scality_user.customer_a_app.arn
    customer-b = scality_user.customer_b_app.arn
  }
}
