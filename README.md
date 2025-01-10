# Cloud Computing Project

This is a project for Cloud Computing.

---

## Base Steps

### Deploying the Original Application in GKE

#### Step 0: Set Up GCP Project and Enable Necessary Services

```bash
export PROJECT_ID=hello-app-123456
gcloud config set project ${PROJECT_ID}
gcloud config set compute/zone europe-west6-a
gcloud services enable compute.googleapis.com container.googleapis.com

