terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.19.0"  
    }
  
    google = {
      source  = "hashicorp/google"
      version ="~>4.0"
      }
  }
}

data "google_client_config" "provider" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.gke_cluster.endpoint}"
  token                  = data.google_client_config.provider.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.gke_cluster.master_auth.0.cluster_ca_certificate)
}

provider "google" {
  region      = "europe-west1"
  project     = var.gcp_projectname
  credentials = file("service-account.json")
  zone        = "europe-west1-b"
}


resource "google_compute_network" "vpc" {
  name = "kartaca-staj"
}

resource "google_compute_subnetwork" "vpc_subnetwork" {
  name          = "kartaca-staj-subnet"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.vpc.self_link
  region        = "europe-west1"

depends_on = [
    google_compute_network.vpc
  ]
}

resource "google_container_cluster" "gke_cluster" {
  name               = "kartacastaj"
  location           = "europe-west1"
  initial_node_count = 1
  network            = google_compute_network.vpc.self_link
  subnetwork         = google_compute_subnetwork.vpc_subnetwork.self_link
  node_config {
    machine_type = "n1-standard-1"
    disk_size_gb = 50
  }
  
  depends_on = [
    google_compute_network.vpc ,  
    google_compute_subnetwork.vpc_subnetwork
  ]


}

resource "kubernetes_deployment" "web" {

  depends_on = [
    google_container_cluster.gke_cluster
  ]

  metadata {
    name = "kartacastaj-deployment"
  }

  spec {
    selector {
      match_labels = {
        app = "kartacastaj"
      }
    }

    template {
      metadata {
        labels = {
          app = "kartacastaj"
        }
      }

      spec {
        container {
          name  = "kartacastaj-container"
          image = "kayretli/kartacastaj:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "kartacasvc" {
  metadata {
    name = "kartacastaj"
  }

  spec {
    selector = {
      app = "kartacastaj"
    }

    port {
      name       = "http"
      port       = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }

  depends_on = [
    kubernetes_deployment.web
  ]
}

output "application_address" {
  value = "http://${kubernetes_service.kartacasvc.status[0].load_balancer[0].ingress[0].ip}"
}
