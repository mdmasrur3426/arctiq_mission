provider "google" {
    project = "arctiq-mission-staging-72622"
    region  = "us-central1"
}

terraform {
  backend "gcs" {
    bucket = "arctiq-mission-tfstate-staging"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
        source  = "hashicorp/google"
        version = "~> 4.0"
    }
  }
}