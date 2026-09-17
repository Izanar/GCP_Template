terraform {
  required_version = ">= 1.9.0"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 8.3" }
    random = { source = "hashicorp/random", version = "~> 3.9" }
  }
}
