#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2023
#
# usage: kubernetes module outputs
#------------------------------------------------------------------------------
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "service_node_group_iam_role_name" {
  value = module.eks.eks_managed_node_groups["smarter"].iam_role_name
}

output "service_node_group_iam_role_arn" {
  value = module.eks.eks_managed_node_groups["smarter"].iam_role_arn
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "kms_key_arn" {
  value = module.eks.kms_key_arn
  description = "ARN of the KMS key used for EKS secrets encryption"
}

output "vpc_id" {
  value = var.vpc_id
}


output "cluster_admin_users" {
  value = var.cluster_admin_users
}

output "cluster_autoscaler_role_arn" {
  value = module.cluster_autoscaler_irsa_role.iam_role_arn
}

output "enable_enhanced_security" {
  value = var.enable_enhanced_security
  description = "Whether or not enhanced security features are enabled for the EKS cluster"
}
