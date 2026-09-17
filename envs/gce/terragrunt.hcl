include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../src/gce"
}

inputs = {
  project_name       = "gcp-template"
  environment        = "dev"
  gcp_region         = get_env("GOOGLE_REGION", "europe-west1")
  zone               = get_env("GOOGLE_ZONE", "${get_env("GOOGLE_REGION", "europe-west1")}-b")
  machine_type       = "e2-micro"
  public_key_path    = get_env("TF_VAR_public_key_path", "~/.ssh/id_rsa.pub")
  ssh_cidr_blocks    = jsondecode(get_env("TF_VAR_ssh_cidr_blocks", "[]"))
  http_cidr_blocks   = ["0.0.0.0/0"]
  https_cidr_blocks  = ["0.0.0.0/0"]
  spot        = true
  budget_email       = get_env("BUDGET_EMAIL", "")
  billing_account    = get_env("BILLING_ACCOUNT", "")
  monthly_budget_usd = 5
}
