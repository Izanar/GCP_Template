# Root Terragrunt configuration
# This file is included by all envs/terragrunt.hcl files

locals {
  # Common settings
  project_name       = "gcp-template"
  environment        = "dev"
  gcp_project        = get_env("GOOGLE_PROJECT", "")
  gcp_region         = get_env("GOOGLE_REGION", "europe-west1")
  budget_email       = get_env("BUDGET_EMAIL", "")
  billing_account    = get_env("BILLING_ACCOUNT", "")
  monthly_budget_usd = 5

  # Optional existing backend. No bucket is created by this template.
  state_bucket = get_env("TF_STATE_BUCKET", "")
  state_prefix = get_env("TF_STATE_PREFIX", "gcp-template")
  local_only   = path_relative_to_include() == "envs/local-wsl"
}

# Persist local state outside the disposable Terragrunt cache.
# GCS supports native locking. Enable object versioning separately for recovery.
generate "backend" {
  path              = "backend.tf.json"
  if_exists         = "overwrite"
  disable_signature = true
  contents = local.state_bucket != "" && !local.local_only ? jsonencode({
    terraform = { backend = { gcs = {
      bucket = local.state_bucket
      prefix = "${local.state_prefix}/${local.gcp_project}/${local.gcp_region}/${path_relative_to_include()}"
    } } }
    }) : jsonencode({
    terraform = { backend = { local = {
      path = "${get_parent_terragrunt_dir()}/${path_relative_to_include()}/terraform.tfstate"
    } } }
  })
}

# Modules own provider constraints for standalone and Terragrunt validation.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.local_only ? "# No cloud provider for local-wsl\n" : <<EOF
provider "google" {
  project = ${local.gcp_project == "" ? "null" : jsonencode(local.gcp_project)}
  region  = "${local.gcp_region}"
}
EOF
}
