# Production Deployment Guide: Distributed Loki on AWS EKS

This guide enables the deployment of a production-grade, cost-optimized Grafana Loki stack capable of handling up to 5 TB of logs per day on AWS EKS.

## 1. Prerequisites & AWS Authentication

Ensure your CLI is authenticated with your primary SSO profile:
```bash
aws sso login --profile <YOUR_AWS_PROFILE>
```

## 2. Infrastructure Provisioning (Terraform)

Deploy the VPC (with S3 Gateway Endpoint), S3 storage, and the EKS Cluster. EKS access is strictly decoupled from personal SSO identities and managed via a dedicated IAM Role.

Copy `infra/terraform.tfvars.example` to `infra/terraform.tfvars` and fill in your values, then:
```bash
cd infra
terraform init
terraform apply -auto-approve
```

## 3. Secure Cluster Access (Role Assumption)

To manage the cluster via `kubectl`, you must assume the `LokiEKSAdminRole`. Using environment variables is the most reliable method to avoid CLI profile-switching issues.

### Run this "Session Link" script:
```bash
# 1. Fetch credentials for the Admin Role
read -r AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN <<< $(aws sts assume-role \
  --role-arn arn:aws:iam::<AWS_ACCOUNT_ID>:role/LokiEKSAdminRole \
  --role-session-name "LokiAdminSession" \
  --profile <YOUR_AWS_PROFILE> \
  --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]" \
  --output text)

# 2. Export to current shell session
export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
unset AWS_PROFILE # Force CLI to use the assumed role credentials

# 3. Update local Kubeconfig
aws eks update-kubeconfig --region eu-central-1 --name loki-prod-cluster
```

## 4. Application Deployment (ECR & K8s)

### A. Build and Push (Multi-Architecture)
Since EKS nodes are `linux/amd64`, you **must** build the image for that architecture, even if developing on an Apple Silicon (ARM64) Mac.

```bash
# Authenticate with ECR (use primary profile)
aws ecr get-login-password --region eu-central-1 --profile <YOUR_AWS_PROFILE> | \
  docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com

# Build and Push using Buildx for AMD64
docker buildx build --platform linux/amd64 \
  -t <AWS_ACCOUNT_ID>.dkr.ecr.eu-central-1.amazonaws.com/poc-app:v1 \
  ./local-app --push
```

### B. Deploy Manifests to EKS:
(Ensure you are using the Admin Context from Step 3)
```bash
kubectl apply -f local-app/kubernetes.yaml
```

## 5. Loki Stack Deployment (Helm)

Install the distributed Loki stack into the `logging` namespace using the optimized production values:

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
kubectl create namespace logging

helm upgrade --install loki grafana/loki \
  -f infra/loki-values.yaml \
  --namespace logging
```

## 6. Verification and Access

1. **Check Pod Status**:
   ```bash
   kubectl get pods -A
   ```

2. **Access Grafana UI**:
   - Get the admin password:
     ```bash
     kubectl get secret --namespace logging loki-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
     ```
   - Port-forward to local machine:
     ```bash
     kubectl port-forward --namespace logging svc/loki-grafana 3000:80
     ```
   - Open `http://localhost:3000` and use `admin` to login.

---

## Senior Architectural Notes

- **Access Management**: The cluster uses **EKS Access Entries** with the `AmazonEKSClusterAdminPolicy` for the `LokiEKSAdminRole`. This provides an auditable, least-privilege administrative path.
- **Cost Optimization**: All log ingestion traffic is routed through the **S3 Gateway Endpoint**, eliminating NAT Gateway data transfer costs for 5 TB/day.
- **Resilience**: The cluster uses **Spot Instances** with a **Replication Factor of 3** in Loki, ensuring data durability during node interruptions.
