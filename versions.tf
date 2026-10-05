terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }

  # Partial configuration: bucket and settings come from backend.hcl.
  #   terraform init -backend-config=backend.hcl
  backend "gcs" {}
}

provider "google" {
  impersonate_service_account = var.terraform_service_account
}
