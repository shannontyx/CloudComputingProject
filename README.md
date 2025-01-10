# Cloud Computing Project

## Prerequisites

Before starting, ensure you have the following installed and configured:

1. **Google Cloud SDK**: Install and configure `gcloud` CLI.
2. **Docker**: Install Docker to build and run containers locally.
3. **Git**: Install Git to clone the repository.

---

## Base Steps

### Deploying the Original Application in GKE [DONE]

**Step 0: Set Up GCP Project and Enable Necessary Services**
```bash
export PROJECT_ID=hello-app-123456
gcloud config set project ${PROJECT_ID}
gcloud config set compute/zone europe-west6-a
gcloud services enable compute.googleapis.com container.googleapis.com
```

**Step 1: Prepare a Directory and Clone the Repository**
```bash
mkdir ~/projects
cd ~/projects
git clone --depth 1 --branch v0 https://github.com/GoogleCloudPlatform/microservices-demo.git
cd microservices-demo/
```

**Step 2: Create the GKE Cluster with Limited Disk Size**
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

**Step 3: Configure kubectl to Use the New Cluster**
```bash
gcloud container clusters get-credentials online-boutique
```

**Step 4: Deploy the Application Using Kubernetes Manifests**

```bash
kubectl apply -f ./release/kubernetes-manifests.yaml
```

**Step 5: Check if All Pods Are Running**
```bash
kubectl get pods
```

**Step 6: Find the External IP of the Frontend Service**
```bash
kubectl get service frontend-external
```
#Example output:
```
NAME                TYPE           CLUSTER-IP       EXTERNAL-IP     PORT(S)        AGE
frontend-external   LoadBalancer   34.118.236.208   34.65.135.210   80:30651/TCP   33m
```

**Step 7: View Logs of the Load Generator to Monitor Traffic**
```bash
kubectl logs -l app=loadgenerator -f
```

### Deploying the Load Generator on a Local Machine 
**Step 8: Navigate to the Load Generator Directory**
```bash
cd ~/projects/microservices-demo/src/loadgenerator/
```
**Step 9: Build the Docker Image for the Load Generator**
```bash
docker build -t loadgenerator .
```

**Step 10: Run the Load Generator with the Frontend's External IP**
```bash
docker run -it --rm loadgenerator -host http://<FRONTEND_IP>
```
Example:
```bash
docker run -it --rm loadgenerator -host http://34.65.135.210
```

**Step 11: Monitor the Logs of the Load Generator**
```bash
# Logs will show the requests being made to the Online Boutique application
# Press Ctrl + C to stop monitoring the logs.
```

**Step 12: Verify the Frontend Service is Accessible**
```bash
kubectl get service frontend-external
```
**Step 13: Open the Application in Your Browser**
```bash
# Replace <FRONTEND_IP> with the external IP of the frontend service http://<FRONTEND_IP>
# Example: http://34.65.135.210
```

### Deploying automatically the load generator in Google Cloud
**Step 1: Create a Directory for Terraform Files**
```bash
cd
mkdir ~/terraform-loadgenerator
cd ~/terraform-loadgenerator
```

**Step 2: Create a Service Account for Terraform**
```bash
gcloud iam service-accounts create terraform-sa \
    --description="Terraform Service Account" \
    --display-name="terraform-sa"

gcloud projects add-iam-policy-binding hello-app-123456 \
    --member="serviceAccount:terraform-sa@hello-app-123456.iam.gserviceaccount.com" \
    --role="roles/editor"

gcloud iam service-accounts keys create ~/terraform-key.json \
    --iam-account=terraform-sa@hello-app-123456.iam.gserviceaccount.com
```

**Step 3: Create the Terraform Configuration File**
```bash
nano main.tf
```
main.tf content for Terraform configuration is inside the main.tf file in this github.

**Step 4: Initialize Terraform**
```bash
terraform init
```

**Step 5: Review the Terraform Plan** 
```bash
terraform plan
```
Enter external IP address when prompted. External IP address can be obtained with the following command.
```bash
kubectl get service frontend-external
```

**Step 6: Apply the Terraform Configuration**
```bash
terraform apply
# Enter external IP address when prompted.
# Confirm with yes when prompted.
# Go to Google Cloud Console -> Compute Engine -> VMs and we can see that loadgenerator-vm has been configured.
```


---

## Advanced Steps
### Monitoring the application and the infrastructure

**Step 1: Prepare the Cluster and Environment**
```bash
kubectl cluster-info
kubectl get nodes
```

**Step 2: Install Helm**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version
```

**Step 3: Create a Namespace for Monitoring**
```bash
kubectl create namespace monitoring
```
**Step 4: Deploy Prometheus and Grafana Using Helm
Add the Prometheus Community Helm Chart Repository**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

**Install the kube-prometheus-stack**
```bash
helm install prometheus prometheus-community/kube-prometheus-stack --namespace monitoring
```

**Step 5: Verify the Installation
Check Pods in the Monitoring Namespace**
```bash
kubectl get pods -n monitoring
```

**Check the Services**
```bash
kubectl get svc -n monitoring
```
**Step 6: Access Grafana**
```bash
kubectl port-forward --namespace monitoring svc/prometheus-grafana 3000:80
```

To access Grafana on local browser, Change the Service Type to LoadBalancer
1. Edit the Service
```bash
kubectl edit svc prometheus-grafana -n monitoring
```

2.Modify the type Field: Change the type from ClusterIP to LoadBalancer:
```bash
spec:
  type: LoadBalancer
```
3. Save and exit the editor.
4. Verify the external IP address (Wait a few minutes for Kubernetes to assign an external IP):
```bash
kubectl get svc -n monitoring
```
Access Grafana on your local browser using:
http://<EXTERNAL-IP>:80

```bash

## Deploying Exporters for Node and Pod Metrics in Kubernetes

To collect information at the node and pod levels for your Grafana dashboard, follow these steps:

---
Deploying Exporters for Node and Pod Metrics in Kubernetes
Step 7: Deploy Node Exporter

7.1 Install Node Exporter with Helm

bash
Copy code
helm install node-exporter prometheus-community/prometheus-node-exporter \
  --namespace monitoring \
  --set service.type=NodePort
7.2 Verify the Deployment Check if the Node Exporter DaemonSet is running:

bash
Copy code
kubectl get daemonsets -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter
Each node in your cluster should have a node-exporter pod.

Step 8: Deploy cAdvisor

8.1 Create a cAdvisor Deployment Create a file called cadvisor-daemonset.yaml and add the following content:

yaml
Copy code
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: monitoring
  labels:
    app: cadvisor
spec:
  selector:
    matchLabels:
      app: cadvisor
  template:
    metadata:
      labels:
        app: cadvisor
    spec:
      containers:
      - name: cadvisor
        image: gcr.io/google-containers/cadvisor:v0.47.0
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
        volumeMounts:
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: var-run
          mountPath: /var/run
          readOnly: true
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: docker
          mountPath: /var/lib/docker
          readOnly: true
      volumes:
      - name: rootfs
        hostPath:
          path: /
      - name: var-run
        hostPath:
          path: /var/run
      - name: sys
        hostPath:
          path: /sys
      - name: docker
        hostPath:
          path: /var/lib/docker
Apply the configuration:

bash
Copy code
kubectl apply -f cadvisor-daemonset.yaml
8.2 Verify the Deployment Check if the cAdvisor DaemonSet is running:

bash
Copy code
kubectl get daemonsets -n monitoring -l app=cadvisor
Step 9: Configure Prometheus to Scrape Metrics

9.1 Edit the Prometheus ConfigMap

bash
Copy code
kubectl edit configmap prometheus-kube-prometheus-prometheus -n monitoring
Add the following scrape configurations under scrape_configs:

yaml
Copy code
- job_name: 'node-exporter'
  static_configs:
  - targets: ['<NODE-EXPORTER-SERVICE>:9100']

- job_name: 'cadvisor'
  static_configs:
  - targets: ['<CADVISOR-SERVICE>:8080']
Replace <NODE-EXPORTER-SERVICE> and <CADVISOR-SERVICE> with the corresponding service names or endpoints.

9.2 Restart Prometheus

bash
Copy code
kubectl delete pod -n monitoring -l app.kubernetes.io/name=prometheus
Step 10: Login to Grafana

Default credentials:

Username: admin
Password: prom-operator
Step 11: Import Grafana Dashboards

11.1 Node Exporter Dashboard

Go to Dashboards > Import in Grafana.
Use Dashboard ID 1860 (Node Exporter Full) from the Grafana website.
Set Prometheus as the data source.
11.2 cAdvisor Dashboard

Go to Dashboards > Import in Grafana.
Use Dashboard ID 14282 (cAdvisor Full Metrics) from the Grafana website.
Set Prometheus as the data source.
Step 12: Verify Metrics Collection

Access the Prometheus web UI via port-forwarding:


kubectl port-forward --namespace monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

http://localhost:9090

```


# Performance Evaluation with Locust
This README provides step-by-step instructions to set up and run Locust for performance evaluation of your application running in a Kubernetes cluster.

**Step 1: Access the VM**
SSH into the VM:
```bash
gcloud compute ssh <VM_NAME> --zone <VM_ZONE>
# example: gcloud compute ssh loadgenerator-vm --zone europe-west6-a
```

Navigate to the home directory of the VM:
```bash
cd ~
```
**Step 2: Set Up Locust on the VM**
Install Python and Pip:
```bash
sudo apt update
sudo apt install -y python3 python3-pip
```

Install Locust:
```bash
pip3 install locust
```

Verify Installation:
```bash
locust --version
```

**Step 3: Create the Locust Test Script**
Write the locustfile.py: Create a test script file in the home directory:
```bash
nano locustfile.py
```
Add Test Scenarios: Paste the following code into locustfile.py:
The locustfile.py is also in the github.
```bash
from locust import HttpUser, task, between

class OnlineBoutiqueUser(HttpUser):
    wait_time = between(1, 3)

    @task(3)
    def browse_products(self):
        self.client.get("/product/1")  # Simulate browsing a product

    @task(1)
    def add_to_cart(self):
        self.client.post("/cart", json={"product_id": 1, "quantity": 1})  # Simulate adding an item to cart
```

Save the file (Ctrl+O, then Enter) and exit (Ctrl+X).

**Step 4: Run Locust**
Start Locust:

```bash
locust -f locustfile.py --host=http://<FRONTEND_EXTERNAL_IP> --csv=results
# Replace <FRONTEND_EXTERNAL_IP> with the external IP of the frontend service from your Kubernetes cluster.
```

#### Access the Locust Web Interface:
Open a browser and navigate to:
http://<VM_EXTERNAL_IP>:8089
Replace <VM_EXTERNAL_IP> with the external IP of your VM.

Configure Test Parameters:

Number of Users: Start with 10 and increase incrementally (e.g., 10, 50, 100).
Spawn Rate: Set to 5 users per second.
Step 5: Analyze Results
Download CSV Files: The --csv=results flag generates CSV files with performance metrics (e.g., response time, failure rates). These files are saved in the VM's home directory.

Generate Graphs: Use tools like Excel, Google Sheets, or Python to create graphs based on the CSV data for analysis.
