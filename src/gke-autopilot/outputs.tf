output "cluster_name" {
  description = "GKE cluster name"
  value       = google_container_cluster.autopilot.name
}

output "cluster_endpoint" {
  description = "GKE cluster endpoint"
  value       = "https://${google_container_cluster.autopilot.endpoint}"
  sensitive   = true
}

output "cluster_location" {
  description = "Region or zone of the cluster"
  value       = google_container_cluster.autopilot.location
}
