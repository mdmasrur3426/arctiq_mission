provider "google" {
    project = "arctiq-mission-prod-3368"
    region  = "us-central1"
}

terraform {
  backend "gcs" {
    bucket = "arctiq-mission-tfstate-prod"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
        source  = "hashicorp/google"
        version = "~> 4.0"
    }
  }
}