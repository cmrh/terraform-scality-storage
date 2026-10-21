# ARTESCA bucket stored on RING

An ARTESCA bucket whose data lives in a RING bucket. Clients use ARTESCA's S3
endpoint; ARTESCA writes, reads and deletes the objects on RING.

- **RING:** an account, an operator, and a versioned bucket with a key that
  can write, read and delete objects (`scality-ring-replication-target`,
  `purpose = "tiering"`).
- **ARTESCA:** a RING location (`artesca-storage-location`), an account, a
  bucket on that location (`artesca-application-bucket` with
  `location_constraint`), and an `app` user with read-write access.

Objects keep their keys at the root of the RING bucket. A permanent delete
through ARTESCA removes the object from RING.

## Run

```sh
# RING (superadmin, creates the RING account)
export SCALITY_ENDPOINT=https://s3.ring.example.com
export SCALITY_ACCESS_KEY=...
export SCALITY_SECRET_KEY=...

# ARTESCA
export ARTESCA_MANAGEMENT_ENDPOINT=https://...
export ARTESCA_OIDC_URL=https://...
export ARTESCA_USERNAME=...
export ARTESCA_PASSWORD=...
export ARTESCA_S3_ENDPOINT=https://...

export TF_VAR_ring_endpoint=https://s3.ring.example.com   # as reached from ARTESCA

terraform init
terraform apply
```

Use an `https://` RING endpoint: the location's key and every object pass
through it.

## Destroy

```sh
TF_VAR_force_destroy=true terraform apply
TF_VAR_force_destroy=true terraform destroy
```

If the destroy stops on a non-empty RING bucket, empty it (every version) and
run the destroy again.
