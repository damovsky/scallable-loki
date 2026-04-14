# Logging System: Grafana Loki PoC

This project demonstrates a low-cost, scalable logging solution based on **Grafana Loki**, replacing expensive CloudWatch Logs.

## Architecture (Simple Scalable Mode)

1.  **Write Path**: Collectors (Fluent Bit, Promtail) send logs to Loki `Write` components (Distributor/Ingester). These group logs into chunks and store them in **AWS S3**.
2.  **Read Path**: Queriers read directly from **AWS S3**. Since the text is not indexed, Loki utilizes massive parallelization for "grepping" content. Indexes are stored in S3 using the TSDB format.
3.  **Storage**: AWS S3 serves as the single storage for both index and data. This dramatically reduces costs (e.g., compared to DynamoDB or OpenSearch).

## PoC Structure

- `infra/`: Terraform for AWS infrastructure (VPC, EKS, S3, IAM roles).
- `infra/loki-values.yaml`: Helm values for deploying Loki to EKS in Simple Scalable mode.
- `local-app/`: Sample application that runs locally and sends logs using Fluent Bit to Loki in AWS.

## How to Run the PoC

Detailed instructions are in [DEPLOYMENT.md](DEPLOYMENT.md).

### 1. Prepare AWS Infrastructure
```bash
cd infra
terraform init
terraform apply
```
*Note: Terraform will create an S3 bucket, VPC, EKS cluster, and IAM roles.*

### 2. Deploy Loki to AWS (EKS)
For production deployment, use Helm:
```bash
helm upgrade --install loki grafana/loki -f infra/loki-values.yaml --namespace logging
```

### 3. Run the Local Application
In the `local-app` directory, provide your Loki address (e.g., Load Balancer) via the `LOKI_HOST` environment variable:
```bash
cd local-app
LOKI_HOST=loki-gateway.your-domain.com docker-compose up --build
```

## Why Loki Meets the Requirements?

- **Cost**: S3 is ~10x cheaper than CloudWatch. Not indexing the full text saves compute power and storage.
- **Scalability**: Designed for petabytes of data (used in Grafana Cloud).
- **Querying**: LogQL allows grepping logs across all services (ECS, EC2, K8s) using labels.
- **ECS Integration**: Using the `awsfirelens` log driver in ECS, integration with Fluent Bit is native and extremely stable.
