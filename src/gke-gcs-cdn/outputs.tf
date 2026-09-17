output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.standard.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = "https://${google_container_cluster.standard.endpoint}"
  sensitive   = true
}

output "audio_bucket_name" {
  description = "Private GCS bucket holding application audio"
  value       = google_storage_bucket.audio.name
}

output "cdn_ip" {
  description = "Public IPv4 of the HTTP forwarding rule for audio"
  value       = google_compute_global_address.audio.address
}
