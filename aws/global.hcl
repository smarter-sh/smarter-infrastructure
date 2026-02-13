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
    iam_admin_user_arn         = get_env("IAM_ADMIN_USER_ARN", "SET-ME-IN-DOT-ENV")
    aws_account_id             = get_env("AWS_ACCOUNT_ID", "SET-ME-IN-DOT-ENV")
    aws_profile                = get_env("AWS_PROFILE", "default")
    aws_region                 = get_env("AWS_REGION", "ca-central-1")
    root_domain                = get_env("ROOT_DOMAIN", "smarter.sh")
    mysql_root_username        = get_env("MYSQL_ROOT_USERNAME", "SET-ME-IN-DOT-ENV")
    mysql_root_password        = get_env("MYSQL_ROOT_PASSWORD", "SET-ME-IN-DOT-ENV")
    unique_id                  = get_env("UNIQUE_ID", "123456789012")
    cost_code                  = get_env("COST_CODE", "smarter")

    platform_region            = "ca"
    shared_resource_identifier = "ubc"
    platform_name              = "smarter"
    api_domain              = "api"
    platform_subdomain         = get_env("PLATFORM_SUBDOMAIN", "platform")
    mysql_host                 = "mysql.service.lawrencemcdaniel.com"
    mysql_port                 = "3306"
    cluster_name               = "${local.platform_name}-${local.shared_resource_identifier}-${local.platform_region}-${local.unique_id}"
    tags = {
      "smarter"                   = "true",
      "terraform"                 = "true",
      "contact"                   = "Lawrence McDaniel - https://lawrencemcdaniel.com/"
      "cost_code"                 = local.cost_code,
      "smarter/root_domain"       = local.root_domain
      "smarter/cluster_name"      = local.cluster_name
      "smarter/mysql_host"        = local.mysql_host
      "smarter/platform_subdomain" = local.platform_subdomain
      "smarter/platform_name"     = local.platform_name,
      "smarter/platform_region"   = local.platform_region,
      "smarter/unique_id"         = local.unique_id
    }

    ###############################################################################
    # CloudWatch logging parameters
    ###############################################################################
    logging_level = "INFO"

    shared_resource_namespace  = "${local.shared_resource_identifier}-${local.aws_region}-${local.shared_resource_identifier}"
    services_subdomain         = "services.${local.root_domain}"
}

inputs = {
    aws_account_id             = local.aws_account_id
    aws_profile                = local.aws_profile
    aws_region                 = local.aws_region
    root_domain                = local.root_domain
    shared_resource_identifier = local.shared_resource_identifier
    cluster_name               = local.cluster_name
    mysql_root_username        = local.mysql_root_username
    mysql_root_password        = local.mysql_root_password
    mysql_host                 = local.mysql_host
    mysql_port                 = local.mysql_port
    api_domain              = local.api_domain
}
