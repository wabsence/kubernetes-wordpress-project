# terraform/modules/iam/outputs.tf - UPDATED

output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_node_role.arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = length(aws_iam_role.aws_load_balancer_controller) > 0 ? aws_iam_role.aws_load_balancer_controller[0].arn : ""
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = length(aws_iam_role.ebs_csi_driver) > 0 ? aws_iam_role.ebs_csi_driver[0].arn : ""
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider"
  value       = length(aws_iam_openid_connect_provider.eks) > 0 ? aws_iam_openid_connect_provider.eks[0].arn : ""
}