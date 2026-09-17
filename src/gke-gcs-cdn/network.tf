resource "google_compute_network" "cluster" {
  name                    = "${var.project_name}-${var.environment}-standard"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "cluster" {
  name                     = "${var.project_name}-${var.environment}-standard"
  region                   = var.gcp_region
  network                  = google_compute_network.cluster.id
  ip_cidr_range            = "10.30.0.0/20"
  private_ip_google_access = true
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.40.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.50.0.0/20"
  }
}
resource "google_service_account" "nodes" {
  account_id   = "${var.project_name}-standard-nodes"
  display_name = "GKE nodes: no application storage or secret access"
}
resource "google_project_iam_member" "nodes" {
  project = data.google_project.current.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.nodes.email}"
}
