output "instance_name" {
  description = "Compute Engine VM name"
  value       = google_compute_instance.web.name
}

output "public_ip" {
  description = "Public IP of the VM"
  value       = google_compute_instance.web.network_interface[0].access_config[0].nat_ip
}

output "url" {
  description = "Application URL"
  value       = "http://${google_compute_instance.web.network_interface[0].access_config[0].nat_ip}"
}
