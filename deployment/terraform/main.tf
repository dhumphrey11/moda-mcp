terraform {
  required_version = ">= 1.5.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
  default     = "us-central1"
}

# Placeholder: define Cloud Run services, service accounts, and IAM here.
# Example skeleton (commented):
# resource "google_cloud_run_v2_service" "features" {
#   name     = "features"
#   location = var.region
#   template {
#     containers {
#       image = "gcr.io/${var.project_id}/features:latest"
#       ports { container_port = 8000 }
#     }
#   }
#   ingress = "INGRESS_TRAFFIC_ALL"
# }
