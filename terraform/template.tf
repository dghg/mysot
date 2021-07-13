
// Cloud Run Resource

locals {
  templatee = tolist([
    "domain.do"
  ])
}


variable "templatee_fe_image_uri" {
  type = string
  default = ""
}

variable "templatee_be_image_uri" {
  type = string
  default = ""
}

resource "random_id" "templatee" {
  byte_length = 4
  prefix = "cert-"
  keepers = {
    domains = join(",", var.templatee_domains)
  }
}

resource "google_compute_managed_ssl_certificate" "templatee" {
  provider = google-beta

  name = random_id.templatee.hex
  managed {
    domains = var.templatee_domains
  }
}

resource "google_cloud_run_service" "templatee_be" { // 수정필요
  name     = "back-templatee" // 수정필요
  location = var.region

  template {
    spec {
      containers {
        image = var.templatee_be_image_uri
		env {
			name = "POSTGRES_HOST"
			value = var.POSTGRES_HOST
		}
		env {
			name = "POSTGRES_USER"
			value = var.POSTGRES_USER
		}
		env {
			name = "POSTGRES_PASSWORD"
			value = var.POSTGRES_PASSWORD
		}
		env {
			name = "POSTGRES_DATABASE"
			value = "db-templatee"
		}

      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "100"
        "run.googleapis.com/cloudsql-instances" = var.cloud_sql
        "run.googleapis.com/client-name"        = "terraform"
      }
      labels = {
        project = "templatee"
      }
    }
  }
  
  traffic {
    percent         = 100
    latest_revision = true
  }
}


resource "google_cloud_run_service" "templatee_fe" { // 수정필요
  name     = "front-templatee" //  수정필요
  location = var.region

  template {
    spec {
      containers {
        image = var.templatee_fe_image_uri
      }
    }
    metadata {
      labels = {
        project = "templatee"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_policy" "templatee_be_noauth" { // 수정필요
  location    = google_cloud_run_service.templatee_be.location
  project     = google_cloud_run_service.templatee_be.project
  service     = google_cloud_run_service.templatee_be.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_run_service_iam_policy" "templatee_fe_noauth" { // 수정필요
  location    = google_cloud_run_service.templatee_fe.location
  project     = google_cloud_run_service.templatee_fe.project
  service     = google_cloud_run_service.templatee_fe.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

// Cloud Build Trigger

/*
resource "google_cloudbuild_trigger" "templatee-trigger-be" {
	trigger_templatee {
	   branch_name = "/\bma./" ## for master, main branch

	}
}
*/


// Cloud Storage Resource

resource "google_storage_bucket" "templatee_storage" {
  
  name          = "storage-templatee"
  location      = "ASIA-NORTHEAST3"
  force_destroy = true

  labels = {
    project = "templatee"
  }


  cors {
    origin          = ["*"]
    method          = ["GET"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_storage_bucket_access_control" "templatee_ac" {
  bucket = google_storage_bucket.templatee_storage.name
  role   = "READER"
  entity = "allUsers"
}

// Serverless NEG ( Cloud Run ) TODO 

resource "google_compute_region_network_endpoint_group" "templatee_neg_fe" {
  provider              = google-beta
  name                  = "templatee-neg-frontend"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.templatee_fe.name
  }
}


resource "google_compute_region_network_endpoint_group" "templatee_neg_be" {
  provider              = google-beta
  name                  = "templatee-neg-backend"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.templatee_be.name
  }
}

// Backend Service

resource "google_compute_backend_bucket" "templatee_static" {
  name        = "templatee-static"
  bucket_name = google_storage_bucket.templatee_storage.name
  enable_cdn  = true
}

resource "google_compute_backend_service" "templatee_frontend" {
	name = "templatee-frontend"
	enable_cdn = true
	backend {
		group = google_compute_region_network_endpoint_group.templatee_neg_fe.id
	}
}

resource "google_compute_backend_service" "templatee_backend" {
	name = "templatee-backend"
	backend {
		group = google_compute_region_network_endpoint_group.templatee_neg_be.id
	}
}

