# Module calls were named ring_* before v2.0.0.
moved {
  from = module.ring_account
  to   = module.ring_s3_account
}

moved {
  from = module.ring_operator
  to   = module.ring_s3_operator
}

moved {
  from = module.ring_bucket
  to   = module.ring_s3_bucket
}
