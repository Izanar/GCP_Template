resource "google_compute_managed_ssl_certificate" "audio" {
  name = "${var.project_name}-${var.environment}-audio"
  managed {
    domains = [var.cdn_domain]
  }
}
resource "google_compute_target_https_proxy" "audio" {
  name             = "${var.project_name}-${var.environment}-audio-https"
  url_map          = google_compute_url_map.audio.id
  ssl_certificates = [google_compute_managed_ssl_certificate.audio.id]
}
resource "google_compute_global_forwarding_rule" "audio_https" {
  name                  = "${var.project_name}-${var.environment}-audio-https"
  target                = google_compute_target_https_proxy.audio.id
  ip_address            = google_compute_global_address.audio.address
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL"
}
variable "cdn_domain" {
  description = "Owned DNS hostname for audio HTTPS. Point its A record to cdn_ip after apply."
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9.-]*[a-z0-9])?\\.[a-z]{2,}$", var.cdn_domain))
    error_message = "Set CDN_DOMAIN to an owned hostname, not an IP or URL."
  }
}
output "cdn_domain" {
  value = var.cdn_domain
}
output "certificate_name" {
  value = google_compute_managed_ssl_certificate.audio.name
}
output "cluster_location" {
  value = google_container_cluster.standard.location
}
