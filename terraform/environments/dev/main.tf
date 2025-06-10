# terraform/environments/dev/main.tf - FIXED VERSION

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket         = "wabsense-k8s-terraform-state-2024"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.common_tags
  }
}

locals {
  project_name = "${var.project_name}-${var.environment}"
  cluster_name = "${local.project_name}-cluster"
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name       = local.project_name
  vpc_cidr          = var.vpc_cidr
  availability_zones = var.availability_zones
  common_tags       = var.common_tags
}

# IAM Module (basic roles first)
module "iam" {
  source = "../../modules/iam"

  project_name        = local.project_name
  eks_oidc_issuer_url = ""  # Empty for first deployment
  common_tags         = var.common_tags
}

# EKS Cluster (basic cluster without IRSA add-ons)
module "eks" {
  source = "../../modules/eks"

  cluster_name             = local.cluster_name
  cluster_role_arn        = module.iam.eks_cluster_role_arn
  node_role_arn           = module.iam.eks_node_role_arn
  ebs_csi_driver_role_arn = ""  # Empty for first deployment
  private_subnet_ids      = module.vpc.private_subnet_ids
  public_subnet_ids       = module.vpc.public_subnet_ids
  kubernetes_version      = var.kubernetes_version
  node_instance_types     = var.node_instance_types
  node_desired_size       = var.node_desired_size
  node_max_size          = var.node_max_size
  node_min_size          = var.node_min_size
  common_tags            = var.common_tags

  depends_on = [module.iam]
}

# Route53 Hosted Zone
resource "aws_route53_zone" "k8s_subdomain" {
  name = "k8s.wabsense.site"

  tags = merge(var.common_tags, {
    Name = "k8s.wabsense.site"
  })
}