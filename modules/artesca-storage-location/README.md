# artesca-storage-location

An ARTESCA storage location backed by a Scality RING bucket, with an optional
S3 endpoint that serves it.

> Compatible with both Terraform and OpenTofu. Examples below use
> `terraform`; substitute `tofu` if you use OpenTofu.

## What it creates

- `artesca_location`: type `location-scality-ring-s3-v1`
- `artesca_endpoint`: when `endpoint_hostname` is set

Use the location as an `artesca-application-bucket` `location_constraint`, or
as a replication destination.

## Prerequisites

- cmrh/artesca provider 1.1 or later.
- A RING bucket, and a key with `s3:GetBucketVersioning`,
  `s3:GetBucketLocation` and `s3:PutObject` on it.
  `scality-ring-replication-target` creates both.
- ARTESCA can reach the RING S3 endpoint. ARTESCA checks the bucket when it
  creates the location.

## Usage

```hcl
module "location" {
  source  = "cmrh/storage/scality//modules/artesca-storage-location"
  version = "~> 1.1"

  name        = "ring-archive"
  endpoint    = "http://ring.example.com:8000"
  bucket_name = module.ring_bucket.bucket_name
  access_key  = module.ring_bucket.access_key
  secret_key  = module.ring_bucket.secret_key
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | (required) | Location name: lowercase letters, numbers and hyphens, starting with a letter. Instance-wide. Forces replacement. |
| `type` | string | `"ring-s3"` | Backend type. Only `ring-s3` for now. Forces replacement. |
| `endpoint` | string | (required) | RING S3 endpoint, as ARTESCA reaches it. |
| `bucket_name` | string | (required) | Target RING bucket. |
| `access_key` | string (sensitive) | (required) | RING key. |
| `secret_key` | string (sensitive) | (required) | Paired with `access_key`. |
| `bucket_match` | bool | `true` | `true`: objects keep their keys at the bucket root. `false`: under a prefix named after the source bucket. Forces replacement. |
| `size_limit_gb` | number | `null` | Storage size limit. |
| `endpoint_hostname` | string | `null` | Hostname for an S3 endpoint serving the location. Forces replacement. |

## Outputs

| Name | Description |
|---|---|
| `name` | Location name. |
| `location_type` | ARTESCA location type. |
| `endpoint_hostname` | Endpoint hostname, or null. |

## Caveats

- **ARTESCA rejects a second location with the same endpoint and bucket**,
  even if `bucket_match` differs.
