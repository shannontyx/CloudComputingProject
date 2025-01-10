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

Challenge: Exceeded CPU size during terraform apply. </br> The 4 nodes consumed all 8 CPUs in the europe-west6 region. Hence, we used the following command to resize the GKE cluster from 4 to 2 nodes to free up some CPU to apply terraform.

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

To access Grafana on local browser, Change the Service Type to LoadBalancer </br>
1. Edit the Service
```bash
kubectl edit svc prometheus-grafana -n monitoring
```

2. Modify the type Field: Change the type from ClusterIP to LoadBalancer:
```bash
spec:
  type: LoadBalancer
```

3. Save and exit the editor. </br>
4. Verify the external IP address (Wait a few minutes for Kubernetes to assign an external IP):
```bash
kubectl get svc -n monitoring
```
Access Grafana on your local browser using:</br>
http://<EXTERNAL-IP>:80


### Deploying Exporters for Node and Pod Metrics in Kubernetes 

Deploying Exporters for Node and Pod Metrics in Kubernetes
**Step 7: Deploy Node Exporter** </br>
7.1 Install Node Exporter with Helm

```bash
helm install node-exporter prometheus-community/prometheus-node-exporter \
  --namespace monitoring \
  --set service.type=NodePort
```
7.2 Verify the Deployment Check if the Node Exporter DaemonSet is running:

```bash
kubectl get daemonsets -n monitoring -l app.kubernetes.io/name=prometheus-node-exporter
```
Each node in your cluster should have a node-exporter pod.

**Step 8: Deploy cAdvisor** </br>
8.1 Create a cAdvisor Deployment </br>
Create a file called cadvisor-daemonset.yaml and add the following content:

```bash
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
```

Apply the configuration:
```bash
kubectl apply -f cadvisor-daemonset.yaml
```
8.2 Verify the Deployment Check if the cAdvisor DaemonSet is running:

```bash
kubectl get daemonsets -n monitoring -l app=cadvisor
```
**Step 9: Configure Prometheus to Scrape Metrics**

9.1 Edit the Prometheus ConfigMap

```bash
kubectl edit configmap prometheus-kube-prometheus-prometheus -n monitoring
```

Add the following scrape configurations under scrape_configs:
```bash
- job_name: 'node-exporter'
  static_configs:
  - targets: ['<NODE-EXPORTER-SERVICE>:9100']

- job_name: 'cadvisor'
  static_configs:
  - targets: ['<CADVISOR-SERVICE>:8080']
```
Replace <NODE-EXPORTER-SERVICE> and <CADVISOR-SERVICE> with the corresponding service names or endpoints.

9.2 Restart Prometheus

```bash
kubectl delete pod -n monitoring -l app.kubernetes.io/name=prometheus
```
**Step 10: Login to Grafana**

Default credentials: </br>

Username: admin </br>
Password: prom-operator </br>
**Step 11: Import Grafana Dashboards**
</br>
11.1 Node Exporter Dashboard </br>

Go to Dashboards > Import in Grafana. </br>
Use Dashboard ID 1860 (Node Exporter Full) from the Grafana website. </br>
Set Prometheus as the data source. </br>
</br>
11.2 cAdvisor Dashboard </br>
Go to Dashboards > Import in Grafana. </br>
Use Dashboard ID 14282 (cAdvisor Full Metrics) from the Grafana website. </br>
Set Prometheus as the data source. </br>

11.3 View Dashboards without cAdvisor </br>
In Grafana, go to Dashboards > Import. </br>
Use popular dashboard IDs from the Grafana community (e.g., Dashboard ID 6417 for Kubernetes cluster monitoring).</br>
Verify Node and Pod Metrics. </br>
View dashboards.

**Step 12: Verify Metrics Collection**

Access the Prometheus web UI via port-forwarding:
```bash
kubectl port-forward --namespace monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```
http://localhost:9090




### Performance Evaluation with Locust
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

**Step 4: Run Locust** </br>
Start Locust:

```bash
locust -f locustfile.py --host=http://<FRONTEND_EXTERNAL_IP> --csv=results
# Replace <FRONTEND_EXTERNAL_IP> with the external IP of the frontend service from your Kubernetes cluster.
```

#### Access the Locust Web Interface:
Open a browser and navigate to:
```bash
http://<VM_EXTERNAL_IP>:8089
Replace <VM_EXTERNAL_IP> with the external IP of your VM.
```
</br>
Challenge faced when accessing Locust web interface (port 8089 not reachable). Troubleshooting and solutions provided in the pdf document.

**Step 5: Configure Test Parameters**

Number of Users: Start with 10 and increase incrementally (e.g., 10, 50, 100).
Spawn Rate: Set to 5 users per second.
The --csv=results flag generates CSV files with performance metrics (e.g., response time, failure rates). These files are saved in the VM's home directory.

**Step 6: Analyze Results**
Download CSV Files:  </br>
Access VM via Google Cloud Console: Go to Compute Engine > VM Instances. </br>
Click SSH for your locust-vm.

In the browser-based SSH terminal:</br>
Click the three-dot menu in the top-right corner. </br>
Select Download File. </br>

Enter the path to the files, e.g., ~/results_stats.csv.


**Step 7: Generate Graphs: Use tools like Excel, Google Sheets, or Python to create graphs based on the CSV data for analysis.**



### Canary releases
**Step 1: Modify the Microservice Code**
Create a New Version (v2):
Clone the existing codebase of productcatalogservice.

Modify a simple string or value to differentiate between v1 and v2. For instance:
Update the welcome message from "Welcome to Product Catalog v1" to "Welcome to Product Catalog v2".

Build a new container image for v2:
```bash
docker build -t gcr.io/<PROJECT_ID>/productcatalogservice:v2 .
docker push gcr.io/<PROJECT_ID>/productcatalogservice:v2
```
**Step 2: Deploy v2 Alongside v1**

Deploy Both Versions:
```bash
Update the Kubernetes manifests to include two deployments for productcatalogservice:
productcatalog-v1 pointing to gcr.io/<PROJECT_ID>/productcatalogservice:v1.
productcatalog-v2 pointing to gcr.io/<PROJECT_ID>/productcatalogservice:v2.
Update the Service Configuration:
```

Use Istio's VirtualService or Kubernetes Ingress to route 25% of the traffic to productcatalog-v2 and 75% to productcatalog-v1. Example using Istio:
```bash
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: productcatalogservice
spec:
  hosts:
  - productcatalogservice
  http:
  - route:
    - destination:
        host: productcatalogservice
        subset: v1
      weight: 75
    - destination:
        host: productcatalogservice
        subset: v2
      weight: 25

```



Apply the Configuration:
```bash
kubectl apply -f virtual-service.yaml

```

**Step 3: Verify Traffic Split**

1. Monitor Logs:
Check the logs of both versions:
```bash

kubectl logs deployment/productcatalog-v1
kubectl logs deployment/productcatalog-v2
```

2. Verify that approximately 25% of the requests are handled by v2 and 75% by v1.
Use Locust:

Generate traffic with Locust and monitor the responses. Verify the version-specific responses (e.g., "Welcome to Product Catalog v1" vs. "Welcome to Product Catalog v2").

3. Use Istio Metrics:

Access the Istio Dashboard in Grafana and analyze the traffic split between the two versions.

**Step 4: Fully Switch to v2**
1. Update the Traffic Split:

Modify the VirtualService configuration to route 100% of the traffic to v2:
```yaml

http:
- route:
  - destination:
      host: productcatalogservice
      subset: v2
    weight: 100
```

2. Apply the Configuration:

```bash

kubectl apply -f virtual-service.yaml
```

3. Scale Down v1:

Once v2 is validated, scale down v1 to 0 replicas to fully decommission it:
```bash

kubectl scale deployment/productcatalog-v1 --replicas=0
```
**Step 5: Extend for Seamless Updates**
</br>
Ensure Zero Downtime:

Use readiness probes to ensure v2 is fully operational before switching traffic.
Configure rolling updates to avoid disruptions for in-flight requests.
Rollback Plan:

Retain the configuration for v1 to quickly revert if issues arise with v2.

## Bonus Steps
### Monitoring the Application and the Infrastructure
**Step 1. Collecting Specific Metrics** </br>
**Step 1.1: Install Dedicated Exporters** </br>
Redis Exporter

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install redis-exporter prometheus-community/prometheus-redis-exporter --namespace monitoring
```

**Step 1.2: Write Custom Exporters**
Write a Python-based exporter using libraries like prometheus_client. </br>
Create a metrics.py file to expose application-specific metrics.</br>
```bash
from prometheus_client import start_http_server, Gauge

g = Gauge('example_metric', 'Description of the metric')
g.set(42)  # Example value

start_http_server(8000)  # Exposes metrics on port 8000
```

Run the exporter alongside your application:

```bash
python3 metrics.py
```
Configure Prometheus to scrape these custom metrics by adding a scrape configuration to prometheus.yaml:

```bash
scrape_configs:
  - job_name: 'custom-exporter'
    static_configs:
      - targets: ['<custom-exporter-IP>:8000']
```
**Step 2. Raising Alerts**
Step 2.1: Configure Alerts </br>
Create an alerting rule file alert-rules.yaml:

```bash
groups:
  - name: example-alerts
    rules:
      - alert: HighCPUUsage
        expr: instance:node_cpu_utilisation:rate5m > 0.8
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 1 minute."
```

Apply the alerting rule to Prometheus:

```bash
kubectl create configmap prometheus-alert-rules --from-file=alert-rules.yaml -n monitoring
kubectl apply -f prometheus-deployment.yaml
```
**Step 2.2: Configure Alert Manager** </br>
Install Alert Manager with Helm:

```bash
helm install alertmanager prometheus-community/prometheus-alertmanager --namespace monitoring
```
Configure Alert Manager to send alerts through email, Slack, or other means. </br>
Configuration:
```bash
global:
  smtp_smarthost: 'smtp.example.com:587'
  smtp_from: 'alertmanager@example.com'
  smtp_auth_username: 'username'
  smtp_auth_password: 'password'
route:
  receiver: 'email-alert'
receivers:
  - name: 'email-alert'
    email_configs:
      - to: 'your-email@example.com'
```

Apply the configuration:
```bash
kubectl apply -f alertmanager-config.yaml
```

