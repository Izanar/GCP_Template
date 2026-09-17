# GKE Autopilot: Google manages nodes, similar operating model to AWS Fargate.
resource "google_container_cluster" "autopilot" {
  name     = "${var.project_name}-${var.environment}-autopilot"
  location = var.gcp_region

  enable_autopilot    = true
  deletion_protection = false


  network    = google_compute_network.cluster.id
  subnetwork = google_compute_subnetwork.cluster.id
  cluster_autoscaling {
    auto_provisioning_defaults { service_account = google_service_account.nodes.email }
  }
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  release_channel { channel = "REGULAR" }
  depends_on = [google_project_iam_member.nodes]

  # Autopilot only schedules on managed capacity; kube-dns needs no extra profile.
  workload_identity_config {
    workload_pool = "${data.google_project.current.project_id}.svc.id.goog"
  }

  resource_labels = {
    environment = var.environment
    project     = var.project_name
  }
}

resource "random_password" "app_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_secret_manager_secret" "app_password" {
  secret_id = "${var.project_name}-${var.environment}-autopilot-password"

  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
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
  display_name    = "${var.project_name}-${var.environment}-monthly-autopilot"

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
