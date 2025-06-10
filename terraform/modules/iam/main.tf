# terraform/modules/iam/main.tf - CORRECTED VERSION

# EKS Cluster Service Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project_name}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# OIDC Provider for EKS (only create if OIDC URL is provided)
data "tls_certificate" "eks" {
  count = var.eks_oidc_issuer_url != "" ? 1 : 0
  url   = var.eks_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = var.eks_oidc_issuer_url != "" ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]
  url             = var.eks_oidc_issuer_url
  tags            = var.common_tags
}

# AWS Load Balancer Controller Role (only create if OIDC provider exists)
resource "aws_iam_role" "aws_load_balancer_controller" {
  count = var.eks_oidc_issuer_url != "" ? 1 : 0
  name  = "${var.project_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

# Download AWS Load Balancer Controller IAM policy (only if needed)
data "http" "aws_load_balancer_controller_policy" {
  count = var.eks_oidc_issuer_url != "" ? 1 : 0
  url   = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "aws_load_balancer_controller" {
  count  = var.eks_oidc_issuer_url != "" ? 1 : 0
  name   = "${var.project_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.aws_load_balancer_controller_policy[0].response_body
  tags   = var.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  count      = var.eks_oidc_issuer_url != "" ? 1 : 0
  policy_arn = aws_iam_policy.aws_load_balancer_controller[0].arn
  role       = aws_iam_role.aws_load_balancer_controller[0].name
}

# EBS CSI Driver Role (only create if OIDC provider exists)
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.eks_oidc_issuer_url != "" ? 1 : 0
  name  = "${var.project_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks[0].arn
        }
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(aws_iam_openid_connect_provider.eks[0].url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count      = var.eks_oidc_issuer_url != "" ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/Amazon_EBS_CSI_DriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}