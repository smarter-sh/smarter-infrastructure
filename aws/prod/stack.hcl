#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Feb-2022
#
# usage: create stack-level parameters, exposed to all
#        Terragrunt modules in this enironment.
#------------------------------------------------------------------------------
locals {
  global_vars = read_terragrunt_config(find_in_parent_folders("global.hcl"))

  stack           = local.global_vars.locals.shared_resource_identifier
  stack_namespace = "${local.global_vars.locals.platform_name}-${local.global_vars.locals.shared_resource_identifier}-${local.global_vars.locals.platform_region}"
  tags = {}

  #----------------------------------------------------------------------------
  # AWS Elastic Kubernetes service
  # Scaling options
  #
  # see: https://aws.amazon.com/ec2/instance-types/
  #----------------------------------------------------------------------------
  kubernetes_cluster_version = "1.35"
  eks_create_kms_key         = false
  arm64_group_min_size       = 3
  arm64_group_max_size       = 10

  eks_service_group_instance_type = "t3.large"
  eks_arm64_group_min_size      = 2
  eks_arm64_group_max_size      = 20
  eks_hosting_group_instance_type = "t3.large"

}
