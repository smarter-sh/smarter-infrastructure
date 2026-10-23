#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Feb-2023
#
# usage: create stack-level parameters, exposed to all
#        Terragrunt modules in this environment.
#------------------------------------------------------------------------------
locals {
  global_vars               = read_terragrunt_config(find_in_parent_folders("global.hcl"))
  environment               = "prod"
  stack_name                = "${local.global_vars.locals.platform_name}-${local.global_vars.locals.shared_resource_identifier}-${local.environment}"
  enable_enhanced_security  = true
  tags                      = {}

  #----------------------------------------------------------------------------
  # AWS Elastic Kubernetes service
  # Scaling options
  #
  # see: https://aws.amazon.com/ec2/instance-types/
  #----------------------------------------------------------------------------
  kubernetes_cluster_version = "1.36"
  eks_create_kms_key         = false
  eks_node_group_min_size    = 3
  eks_node_group_max_size    = 15
  # The smarter Docker container is built for both AMD64 and ARM64 architectures,
  # so we can use either type of instance. AMD64 is the more common of the two,
  # so this is our default.
  #
  # Every type has at least 8 GiB of memory. The compute optimized c-family
  # .large types have 4 GiB, which the smarter app pod (a 2Gi request) and the
  # Celery workers outgrow together during a rolling deploy: the node runs out
  # of memory and the kubelet evicts pods.
  amd64_instance_types       = [
    "t3.large",
    "t3a.large",
    "m5a.large",
    "m6a.large",
    "m5.large",
    "m4.large",
  ]
  graviton_instance_types    = [
    "t4g.large",
    "m6g.large",
    "r6g.large",
    "m7g.large",
    "r7g.large",
    "r8g.large",
    "m8g.large"
  ]
  eks_node_group_instance_types = local.amd64_instance_types
}
