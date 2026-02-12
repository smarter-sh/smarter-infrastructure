#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Feb-2024
#
# usage: create global parameters, exposed to all
#        Terragrunt modules in this repository.
#------------------------------------------------------------------------------
generate "random_string" {
  path      = "random_string.auto.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
resource "random_string" "unique_id" {
  length  = 8
  upper   = true
  lower   = true
  number  = true
  special = false
}

output "unique_id" {
  value = random_string.unique_id.result
}
EOF
}

locals {

    ###############################################################################
    # AWS CLI parameters
    ###############################################################################
    iam_admin_user_arn         = get_env("IAM_ADMIN_USER_ARN", "SET-ME-IN-DOT-ENV")
    api_subdomain              = "api"
    aws_account_id             = get_env("AWS_ACCOUNT_ID", "SET-ME-IN-DOT-ENV")
    aws_profile                = get_env("AWS_PROFILE", "default")
    aws_region                 = get_env("AWS_REGION", "ca-central-1")
    root_domain                = get_env("ROOT_DOMAIN", "smarter.sh")
    mysql_root_username        = get_env("MYSQL_ROOT_USERNAME", "SET-ME-IN-DOT-ENV")
    mysql_root_password        = get_env("MYSQL_ROOT_PASSWORD", "SET-ME-IN-DOT-ENV")

    platform_region            = "ca"
    shared_resource_identifier = "ubc"
    platform_name              = "smarter"
    eks_cluster_name           = "${local.shared_resource_identifier}-${local.platform_region}"
    platform_subdomain         = get_env("PLATFORM_SUBDOMAIN", "platform")
    mysql_host                 = "mysql.service.lawrencemcdaniel.com"
    mysql_port                 = "3306"
    tags = {
      "smarter"                   = "true",
      "cost_code"                 = get_env("COST_CODE", "smarter"),
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
    unique_id                   = random_string.unique_id.result

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
