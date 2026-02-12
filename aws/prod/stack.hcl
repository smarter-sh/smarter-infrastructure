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
  eks_node_group_min_size       = 3
  eks_node_group_max_size       = 10

  amd64_instance_types = [
    "t3.large",
    "t3a.large",
    "m5a.large",
    "m6a.large",
    "m5.large",
    "m4.large",
    "m5.large",
    "c5.large",
  ]
  graviton_instance_types = [
    "t4g.large",
    "c6g.large",
    "m6g.large",
    "r6g.large",
    "c7g.large",
    "m7g.large",
    "r7g.large",
    "c8g.large",
    "r8g.large",
    "m8g.large"
  ]
  eks_node_group_instance_types = local.amd64_instance_types

}
