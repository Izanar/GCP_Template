include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../src/gke-autopilot"
}

inputs = {
  project_name       = "gcp-template"
  environment        = "dev"
  gcp_region         = get_env("GOOGLE_REGION", "europe-west1")
  budget_email       = get_env("BUDGET_EMAIL", "")
  billing_account    = get_env("BILLING_ACCOUNT", "")
  monthly_budget_usd = 5
}
