# GKE Standard cluster plus a private GCS audio bucket delivered through Cloud CDN.
resource "google_container_cluster" "standard" {
  name     = "${var.project_name}-${var.environment}-standard"
  location = var.gcp_region

  deletion_protection      = false
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.cluster.id
  subnetwork = google_compute_subnetwork.cluster.id
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  release_channel { channel = "REGULAR" }
  depends_on = [google_project_iam_member.nodes]

  workload_identity_config {
    workload_pool = "${data.google_project.current.project_id}.svc.id.goog"
  }
  node_config {
    service_account = google_service_account.nodes.email
    # Isolate pod identity from node credentials.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  resource_labels = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "google_container_node_pool" "default" {
  name     = "default"
  location = var.gcp_region
  cluster  = google_container_cluster.standard.name

  initial_node_count = var.node_desired_size

  autoscaling {
    total_min_node_count = var.node_min_size
    total_max_node_count = var.node_max_size
  }

  node_config {
    service_account = google_service_account.nodes.email
    workload_metadata_config { mode = "GKE_METADATA" }
    machine_type = var.node_machine_type
    disk_size_gb = 20
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"
    spot         = var.node_spot
    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      environment = var.environment
      project     = var.project_name
    }
  }
}

resource "google_storage_bucket" "audio" {
  name                        = "${var.project_name}-${var.environment}-audio-${data.google_project.current.number}"
  location                    = var.gcp_region
  force_destroy               = var.force_destroy_bucket
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      with_state                 = "ARCHIVED"
      days_since_noncurrent_time = 7
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    environment = var.environment
    project     = var.project_name
    purpose     = "audio"
  }
}

data "google_project" "current" {}

# The HTTPS load balancer service agent is created after the first backend bucket.
# It can read the private origin without requiring viewer-side signed URLs.
resource "google_storage_bucket_iam_member" "cdn_reader" {
  bucket = google_storage_bucket.audio.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:service-${data.google_project.current.number}@https-lb.iam.gserviceaccount.com"

  depends_on = [google_compute_backend_bucket.audio]
}

resource "google_compute_backend_bucket" "audio" {
  name        = "${var.project_name}-${var.environment}-audio"
  bucket_name = google_storage_bucket.audio.name
  enable_cdn  = true

  cdn_policy {
    cache_mode  = "FORCE_CACHE_ALL"
    default_ttl = 3600
    max_ttl     = 86400
    client_ttl  = 3600
  }
}

resource "google_compute_global_address" "audio" {
  name = "${var.project_name}-${var.environment}-audio-ip"
}

resource "google_compute_target_http_proxy" "audio" {
  name    = "${var.project_name}-${var.environment}-audio-proxy"
  url_map = google_compute_url_map.https_redirect.id
}

resource "google_compute_url_map" "audio" {
  name            = "${var.project_name}-${var.environment}-audio-map"
  default_service = google_compute_backend_bucket.audio.self_link
}

resource "google_compute_global_forwarding_rule" "audio" {
  name                  = "${var.project_name}-${var.environment}-audio-rule"
  target                = google_compute_target_http_proxy.audio.self_link
  ip_address            = google_compute_global_address.audio.self_link
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
}

resource "random_password" "app_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret" "app_password" {
  secret_id = "${var.project_name}-${var.environment}-standard-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_password" {
  secret = google_secret_manager_secret.app_password.id
  secret_data = jsonencode({
    password = random_password.app_password.result
  })
}

resource "google_monitoring_notification_channel" "budget_email" {
  count        = local.budget_enabled ? 1 : 0
  display_name = "${var.project_name}-${var.environment}-budget-email"
  type         = "email"
  labels = {
    email_address = var.budget_email
  }
}

resource "google_billing_budget" "project" {
  count = local.budget_enabled ? 1 : 0

  billing_account = var.billing_account
  display_name    = "${var.project_name}-${var.environment}-monthly-gcs"

  budget_filter {
    projects = ["projects/${data.google_project.current.number}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.monthly_budget_usd)
    }
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.budget_email[0].id]
  }
}

locals {
  budget_enabled = trimspace(var.budget_email) != "" && trimspace(var.billing_account) != ""
}

resource "google_compute_url_map" "https_redirect" {
  name = "${var.project_name}-${var.environment}-audio-redirect"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}
