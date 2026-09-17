resource "random_string" "instance_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

resource "google_compute_network" "web" {
  name                    = "${var.project_name}-${var.environment}-gce"
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "web" {
  name          = "${var.project_name}-${var.environment}-gce"
  region        = var.gcp_region
  network       = google_compute_network.web.id
  ip_cidr_range = "10.20.0.0/24"
}

resource "google_compute_firewall" "ssh" {
  count         = length(var.ssh_cidr_blocks) > 0 ? 1 : 0
  name          = "${var.project_name}-${var.environment}-allow-ssh-${random_string.instance_suffix.result}"
  network       = google_compute_network.web.id
  description   = "Allow SSH to the demo VM"
  direction     = "INGRESS"
  source_ranges = var.ssh_cidr_blocks

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["${var.project_name}-web"]
}

resource "google_compute_firewall" "web" {
  for_each      = { for port, ranges in { "80" = var.http_cidr_blocks, "443" = var.https_cidr_blocks } : port => ranges if length(ranges) > 0 }
  name          = "${var.project_name}-${var.environment}-web-${each.key}"
  network       = google_compute_network.web.id
  source_ranges = each.value
  allow {
    protocol = "tcp"
    ports    = [each.key]
  }
  target_tags = ["${var.project_name}-web"]
}

resource "google_compute_instance" "web" {
  name         = "${var.project_name}-${var.environment}-web"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_image
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.web.id
    access_config {} # ephemeral public IP
  }

  # Instance-level SSH key does not modify project-wide metadata.
  metadata = {
    block-project-ssh-keys = "true"
    enable-oslogin         = "FALSE"
    ssh-keys               = "ubuntu:${trimspace(file(pathexpand(var.public_key_path)))}"
  }

  tags = ["${var.project_name}-web"]

  labels = {
    environment = var.environment
    project     = var.project_name
  }

  # Spot VMs can be interrupted; STOP keeps the managed VM recoverable.
  scheduling {
    provisioning_model          = var.spot ? "SPOT" : "STANDARD"
    preemptible                 = var.spot
    automatic_restart           = !var.spot
    on_host_maintenance         = var.spot ? "TERMINATE" : "MIGRATE"
    instance_termination_action = var.spot ? "STOP" : null
  }

  deletion_protection = false
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
  display_name    = "${var.project_name}-${var.environment}-monthly-gce"

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

data "google_project" "current" {}
