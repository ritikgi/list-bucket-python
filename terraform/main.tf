# VPC Setup
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

# Public Subnet 1 (us-west-2a)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2a"
}

# Public Subnet 2 (us-west-2b)
resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-west-2b"
}

# Private Subnet (us-west-2c)
resource "aws_subnet" "private_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-west-2c"
}

# Public Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB (Allow inbound HTTP traffic)
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Effect    = "Allow",
        Sid       = ""
      }
    ]
  })
}

# Attach EKS Cluster Policy to IAM Role
resource "aws_iam_role_policy_attachment" "eks_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_role.name
}

# EKS Cluster Definition
resource "aws_eks_cluster" "main" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_role_policy_attachment]
}

# Define the AWS EKS Cluster Authentication Data Source
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# Kubernetes Provider for Terraform
provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.main.token
}

# IAM Role for Fargate Pod Execution
resource "aws_iam_role" "eks_fargate_role" {
  name = "eks-fargate-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Principal = {
          Service = [
            "eks.amazonaws.com",
            "eks-fargate.amazonaws.com" # Add this to the trust policy
          ]
        },
        Effect    = "Allow",
        Sid       = ""
      }
    ]
  })
}

# Attach policies for Fargate Pod Execution
resource "aws_iam_role_policy_attachment" "eks_fargate_role_policy_attachment" {
  role       = aws_iam_role.eks_fargate_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

# Fargate Profile for EKS
resource "aws_eks_fargate_profile" "main" {
  cluster_name         = aws_eks_cluster.main.name
  fargate_profile_name = "fargate-profile"
  
  pod_execution_role_arn = aws_iam_role.eks_fargate_role.arn

  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  selector {
    namespace = "default"
  }
}

# Kubernetes Deployment using Docker Image
resource "kubernetes_deployment" "app_deployment" {
  metadata {
    name      = "one2n-python-deployment"
    namespace = "default"
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "one2n-python"
      }
    }
    template {
      metadata {
        labels = {
          app = "one2n-python"
        }
      }

      spec {
        container {
          name  = "one2n-python"
          image = "ritik8823/one2n-python:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

# Kubernetes Service to expose the Deployment
resource "kubernetes_service" "app_service" {
  metadata {
    name      = "one2n-python-service"
    namespace = "default"
  }

  spec {
    selector = {
      app = "one2n-python"
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "web_alb" {
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]
  enable_deletion_protection = false
}

# ALB Listener
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# ALB Target Group for Kubernetes Service
resource "aws_lb_target_group" "web_tg" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Output the ALB URL (this will give you the endpoint)
output "alb_url" {
  value = aws_lb.web_alb.dns_name
}
