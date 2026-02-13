#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com
#
# date: Mar-2022
#
# usage: build an EKS with EC2 worker nodes and ALB
#------------------------------------------------------------------------------
locals {
  # Automatically load stack-level variables
  stack_vars  = read_terragrunt_config(find_in_parent_folders("stack.hcl"))
  global_vars = read_terragrunt_config(find_in_parent_folders("global.hcl"))

  iam_admin_user_arn       = local.global_vars.locals.iam_admin_user_arn

  # Extract out common variables for reuse
  unique_id                   = local.global_vars.locals.unique_id
  namespace                  = local.stack_vars.locals.stack_name
  cluster_name               = local.global_vars.locals.cluster_name
  root_domain                = local.global_vars.locals.root_domain
  platform_name              = local.global_vars.locals.shared_resource_identifier
  platform_region            = local.global_vars.locals.platform_region
  aws_account_id             = local.global_vars.locals.aws_account_id
  aws_region                 = local.global_vars.locals.aws_region
  shared_resource_identifier = local.global_vars.locals.shared_resource_identifier
  kubernetes_cluster_version = local.stack_vars.locals.kubernetes_cluster_version
  eks_create_kms_key         = local.stack_vars.locals.eks_create_kms_key
  eks_node_group_min_size    = local.stack_vars.locals.eks_node_group_min_size
  eks_node_group_max_size    = local.stack_vars.locals.eks_node_group_max_size
  eks_node_group_instance_types = local.stack_vars.locals.eks_node_group_instance_types

  # mcdaniel: FIX NOTE
  # we need to make a hard decision about whether or not we need to create a
  # bastion server for each cluster, or if we can get by with one bastion
  # server that has access to all clusters.
  # bastion_iam_arn            = "arn:aws:iam::${local.aws_account_id}:user/system/bastion-user/${local.namespace}-bastion"
  bastion_iam_arn            = "arn:aws:iam::090511222473:user/system/bastion-user/apps-hosting-service-bastion"
  bastion_iam_username       = "${local.namespace}-bastion"

  tags = merge(
    local.stack_vars.locals.tags,
    local.global_vars.locals.tags,
    {
    "create_kms_key" = local.stack_vars.locals.eks_create_kms_key,
    }
  )
}

dependency "vpc" {
  config_path = "../vpc"

  # Configure mock outputs for the `validate` and `init` commands that are returned when there are no outputs available (e.g the
  # module hasn't been applied yet.
  mock_outputs_allowed_terraform_commands = ["init", "validate", "destroy"]
  mock_outputs = {
    vpc_id           = "fake-vpc-id"
    public_subnets   = ["fake-public-subnet-01", "fake-public-subnet-02"]
    private_subnets  = ["fake-private-subnet-01", "fake-private-subnet-02"]
    database_subnets = ["fake-database-subnet-01", "fake-database-subnet-02"]
  }

}

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder.
terraform {
  source = "../../terraform/kubernetes"
  before_hook "before_init" {
    commands = ["init"]
    execute  = ["echo", "Initializing module in ${get_terragrunt_dir()}"]
  }
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
inputs = {
  iam_admin_user_arn         = local.iam_admin_user_arn
  aws_account_id             = local.aws_account_id
  shared_resource_identifier = local.shared_resource_identifier
  aws_region                 = local.aws_region
  root_domain                = local.root_domain
  namespace                  = local.namespace
  cluster_name               = local.cluster_name
  private_subnets            = dependency.vpc.outputs.private_subnets
  public_subnets             = dependency.vpc.outputs.public_subnets
  vpc_id                     = dependency.vpc.outputs.vpc_id
  kubernetes_cluster_version = local.kubernetes_cluster_version
  eks_create_kms_key         = local.eks_create_kms_key
  bastion_iam_arn            = local.bastion_iam_arn
  tags                       = local.tags
  eks_node_group_instance_types = local.eks_node_group_instance_types

  eks_node_group_min_size     = local.eks_node_group_min_size
  eks_node_group_max_size     = local.eks_node_group_max_size
  unique_id                   = local.unique_id

  # -------------------------------------------------------------------------
  # NOTE: uncomment if you are using KMS encryption for EKS secrets and want
  # to add additional cluster admin users to the KMS key owner list.
  # You will also need to add these users to the map_users variable below
  # so they can authenticate to the cluster and manage the KMS key.
  # ADD MORE CLUSTER ADMIN USER IAM ACCOUNTS TO THE AWS KMS KEY OWNER LIST:
  # -------------------------------------------------------------------------
  kms_key_owners = [
    "${local.bastion_iam_arn}",
    "${local.iam_admin_user_arn}",
  ]
  cluster_admin_users = [
    "${local.iam_admin_user_arn}",
  ]

}
