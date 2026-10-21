output "name" {
  value       = artesca_location.this.name
  description = "Location name, for artesca-application-bucket's location_constraint or a replication rule's destination_location."
}

output "location_type" {
  value       = artesca_location.this.location_type
  description = "ARTESCA location type."
}

output "endpoint_hostname" {
  value       = try(artesca_endpoint.this[0].hostname, null)
  description = "Hostname of the endpoint serving this location, or null."
}
