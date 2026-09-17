include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../src/gke-gcs-cdn"
}

inputs = {
  cdn_domain = get_env("CDN_DOMAIN", "")
  project_name         = "gcp-template"
  environment          = "dev"
  gcp_region           = get_env("GOOGLE_REGION", "europe-west1")
  node_machine_type    = "e2-small"
  node_desired_size    = 1
  node_min_size        = 1
  node_max_size        = 2
  node_spot            = true
  force_destroy_bucket = true
  budget_email         = get_env("BUDGET_EMAIL", "")
  billing_account      = get_env("BILLING_ACCOUNT", "")
  monthly_budget_usd   = 5
}
