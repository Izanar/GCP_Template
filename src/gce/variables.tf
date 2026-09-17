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

variable "zone" {
  description = "GCP zone for the VM"
  type        = string
  default     = "europe-west1-b"
}

variable "machine_type" {
  description = "GCE machine type"
  type        = string
  default     = "e2-micro"
}

variable "boot_image" {
  description = "Boot disk image family"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "public_key_path" {
  description = "Path to the SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_cidr_blocks" {
  description = "CIDR ranges allowed to reach SSH on the VM"
  type        = list(string)
  default     = []
}

variable "http_cidr_blocks" {
  description = "CIDR ranges allowed to reach HTTP"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "https_cidr_blocks" {
  description = "CIDR ranges allowed to reach HTTPS"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "spot" {
  description = "Use Compute Engine Spot capacity"
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
