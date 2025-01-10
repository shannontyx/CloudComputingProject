# Cloud Computing Project

## Prerequisites

Before starting, ensure you have the following installed and configured:

1. **Google Cloud SDK**: Install and configure `gcloud` CLI.
2. **Docker**: Install Docker to build and run containers locally.
3. **Git**: Install Git to clone the repository.

---

## Base Steps

### Deploying the Original Application in GKE [DONE]

#### Step 0: Set Up GCP Project and Enable Necessary Services

```bash
export PROJECT_ID=hello-app-123456
gcloud config set project ${PROJECT_ID}
gcloud config set compute/zone europe-west6-a
gcloud services enable compute.googleapis.com container.googleapis.com

#### Step 1: Prepare a Directory and Clone the Repository
```bash
mkdir ~/projects
cd ~/projects
git clone --depth 1 --branch v0 https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo/
```

####Step 2: Create the GKE Cluster with Limited Disk Size
```bash
gcloud container clusters create online-boutique \
  --num-nodes=4 \
  --machine-type=e2-standard-2 \
  --disk-size=30
```

Challenge: Exceeded CPU size during terraform apply. The 4 nodes consumed all 8 CPUs in the europe-west6 region. Resized the GKE cluster to 2 nodes.

```bash
gcloud container clusters resize online-boutique \
  --num-nodes=2 \
  --region=europe-west6
```

####Step 3: Configure kubectl to Use the New Cluster
```bash
gcloud container clusters get-credentials online-boutique
```

####Step 4: Deploy the Application Using Kubernetes Manifests

```bash
kubectl apply -f ./release/kubernetes-manifests.yaml
```

####Step 5: Check if All Pods Are Running
```bash
kubectl get pods
```

####Step 6: Find the External IP of the Frontend Service
```bash
kubectl get service frontend-external
```
Example output:

scss
Copy code
NAME                TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
frontend-external   LoadBalancer   34.118.236.208   34.65.135.210   80:30651/TCP   33m
Step 7: View Logs of the Load Generator to Monitor Traffic
bash
Copy code
kubectl logs -l app=loadgenerator -f
Deploying the Load Generator on a Local Machine [DONE]
Step 8: Navigate to the Load Generator Directory
bash
Copy code
cd ~/projects/microservices-demo/src/loadgenerator/
Step 9: Build the Docker Image for the Load Generator
bash
Copy code
docker build -t loadgenerator .
Step 10: Run the Load Generator with the Frontend's External IP
bash
Copy code
docker run -it --rm loadgenerator -host http://<FRONTEND_IP>
Example:

bash
Copy code
docker run -it --rm loadgenerator -host http://34.65.135.210
Step 11: Monitor the Logs of the Load Generator
bash
Copy code
# Logs will show the requests being made to the Online Boutique application
# Press Ctrl + C to stop monitoring the logs.
Step 12: Verify the Frontend Service is Accessible
bash
Copy code
kubectl get service frontend-external
Example output:

scss
Copy code
NAME                TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
frontend-external   LoadBalancer   34.118.231.108   34.65.191.236   80:30339/TCP   6m54s
Step 13: Open the Application in Your Browser
bash
Copy code
# Replace <FRONTEND_IP> with the external IP of the frontend service
http://<FRONTEND_IP>
Example:

bash
Copy code
http://34.65.135.210
Terraform Integration
Step 1: Create a Service Account for Terraform
bash
Copy code
gcloud iam service-accounts create terraform-sa \
    --description="Terraform Service Account" \
    --display-name="terraform-sa"

gcloud projects add-iam-policy-binding hello-app-123456 \
    --member="serviceAccount:terraform-sa@hello-app-123456.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud iam service-accounts keys create ~/terraform-key.json \
    --iam-account=terraform-sa@hello-app-123456.iam.gserviceaccount.com
Step 2: Create the Terraform Configuration File
bash
Copy code
nano main.tf
Add the following Terraform configuration:

hcl
Copy code
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
Step 3: Push the Docker Image to Google Container Registry
bash
Copy code
docker tag loadgenerator gcr.io/hello-app-123456/loadgenerator
docker push gcr.io/hello-app-123456/loadgenerator
Step 4: Initialize Terraform
bash
Copy code
terraform init
Step 5: Review the Terraform Plan
bash
Copy code
terraform plan
Step 6: Apply the Terraform Configuration
bash
Copy code
terraform apply
Confirm with yes when prompted.
