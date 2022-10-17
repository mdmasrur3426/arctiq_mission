provider "google" {
    project = "arctiq-mission-masrur"
    region  = "us-central1"
}

terraform {
  backend "gcs" {
    bucket = "arctiq-mission-tf-state-staging"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
        source  = "hashicorp/google"
        version = "~> 4.0"
    }
  }
}