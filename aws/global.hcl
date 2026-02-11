#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Feb-2024
#
# usage: create global parameters, exposed to all
#        Terragrunt modules in this repository.
#------------------------------------------------------------------------------
locals {

    ###############################################################################
    # AWS CLI parameters
    ###############################################################################
    api_subdomain              = "api"
    aws_account_id             = get_env("AWS_ACCOUNT_ID", "SET-ME-PLEASE")
    aws_profile                = get_env("AWS_PROFILE", "default")
    aws_region                 = get_env("AWS_REGION", "ca-central-1")
    root_domain                = get_env("ROOT_DOMAIN", "smarter.sh")
    mysql_root_username        = get_env("MYSQL_ROOT_USERNAME", "SET-ME-PLEASE")
    mysql_root_password        = get_env("MYSQL_ROOT_PASSWORD", "SET-ME-PLEASE")

    platform_region            = "ca"
    shared_resource_identifier = "ubc"
    platform_name              = "smarter"
    eks_cluster_name           = "${local.shared_resource_identifier}-${local.platform_region}"
    platform_subdomain         = get_env("PLATFORM_SUBDOMAIN", "platform")
    mysql_host                 = "mysql.service.lawrencemcdaniel.com"
    mysql_port                 = "3306"
    tags = {
      "smarter"                   = "true",
      "ubc"                       = "true",
      "terraform"                 = "true",
      "platform_name"             = local.platform_name,
      "platform_region"           = local.platform_region,
      "contact"                   = "Lawrence McDaniel - https://lawrencemcdaniel.com/"
      "smarter/root_domain"       = local.root_domain
      "smarter/eks_cluster_name"  = local.eks_cluster_name
      "smarter/mysql_host"        = local.mysql_host
      "smarter/platform_subdomain" = local.platform_subdomain
    }

    ###############################################################################
    # CloudWatch logging parameters
    ###############################################################################
    logging_level = "INFO"

    shared_resource_namespace  = "${local.shared_resource_identifier}-${local.aws_region}-${local.shared_resource_identifier}"
    services_subdomain         = "${local.shared_resource_identifier}.${local.root_domain}"

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

inputs = {
    aws_account_id             = local.aws_account_id
    aws_profile                = local.aws_profile
    aws_region                 = local.aws_region
    root_domain                = local.root_domain
    shared_resource_identifier = local.shared_resource_identifier
    eks_cluster_name           = local.eks_cluster_name
    mysql_root_username        = local.mysql_root_username
    mysql_root_password        = local.mysql_root_password
    mysql_host                 = local.mysql_host
    mysql_port                 = local.mysql_port
    api_subdomain              = local.api_subdomain
}
