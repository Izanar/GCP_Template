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
