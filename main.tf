provider "google" {
  credentials = file("~/terraform-key.json")
  project     = "hello-app-123456"
  region      = "europe-west6"
  zone        = "europe-west6-a"
}

variable "frontend_ip" {
  description = "The external IP address of the frontend service"
  type        = string
}

resource "google_compute_instance" "loadgenerator" {
  name         = "loadgenerator-vm"
  machine_type = "e2-micro"
  zone         = "europe-west6-a"

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-11"
    }
  }

  network_interface {
    network = "default"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    docker pull gcr.io/hello-app-123456/loadgenerator
    docker run -d --name=loadgenerator --restart=always gcr.io/hello-app-123456/loadgenerator -host http://${var.frontend_ip}
  EOT
}
