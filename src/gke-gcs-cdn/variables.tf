variable "project_name" {
  description = "Base project name"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "gcp_region" {
  description = "GCP region"
  type        = string
}

variable "node_machine_type" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-small"
}

variable "node_desired_size" {
  description = "Initial number of nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Autoscaling minimum"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Autoscaling maximum"
  type        = number
  default     = 2
}

variable "node_spot" {
  description = "Use Spot VMs for the node pool"
  type        = bool
  default     = true
}

variable "force_destroy_bucket" {
  description = "Empty and destroy the audio bucket on destroy"
  type        = bool
  default     = true
}

variable "budget_email" {
  description = "Optional email for the monthly budget alert"
  type        = string
  default     = ""
}

variable "billing_account" {
  description = "Billing account ID for the optional budget"
  type        = string
  default     = ""
}

variable "monthly_budget_usd" {
  description = "Optional budget threshold in USD"
  type        = number
  default     = 5
}
