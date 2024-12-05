
# List Bucket Python Main

This project demonstrates listing S3 bucket contents using a Python application and infrastructure as code (IaC) with Terraform.

## Prerequisites
- Python 3.8+ installed on your local machine.
- AWS CLI installed and configured with appropriate permissions.
- Terraform installed (v1.3+).
- Docker installed if containerizing the application.

## Architecture Overview
In this project, the infrastructure is set up using AWS Fargate for the Kubernetes pods to avoid the need to manage EC2 instances. Amazon EKS is used for orchestrating the containers, while the Application Load Balancer (ALB) handles the traffic routing.

Components:
VPC: Defines the virtual network, with both public and private subnets.
EKS Cluster: Managed Kubernetes cluster using AWS EKS.
Fargate Profile: Uses AWS Fargate for managing the Kubernetes workloads without EC2 instances.
IAM Roles: Ensures appropriate permissions for EKS and Fargate to operate securely.
Application Load Balancer (ALB): Exposes the Kubernetes service to the internet.
Kubernetes Deployment: Deploys the Python application on the Kubernetes cluster.
Kubernetes Service: Exposes the application via a LoadBalancer type service, automatically integrating with the ALB.

## Assumptions
- You have access to an AWS account.
- Necessary IAM roles and policies are in place for S3 and EC2.

## Project Structure
```
updated-list-bucket-python-main/
├── README.md
├── .gitignore
├── app/
│   ├── app.py
│   ├── Dockerfile
├── terraform/
│   ├── main.tf
│   ├── provider.tf
│   ├── output.tf
│   ├── variables.tf
│   ├── terraform.tfvars
└── Documentation (screenshots and demo images)
```

## Steps to Execute the Code
1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd updated-list-bucket-python-main
   ```

2. Set up Terraform:
   ```bash
   cd terraform
   terraform init
   terraform plan
   terraform apply
   ```

3. Run the Python application locally:
   ```bash
   cd ../app
   python app.py
   ```

4. To run using Docker:
   ```bash
   docker build -t list-bucket-app .
   docker run -p 5000:5000 list-bucket-app
   ```

## Demo
Refer to the included images (`api-res-1.png`, `api-res-2.png`, etc.) for application screenshots.

