#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      Smarter app infrastructure - set environment variables and tags
#             for this environment.
#------------------------------------------------------------------------------

locals {
  environment                   = var.environment
  environment_namespace         = lower("${var.environment_name}")
  environment_marketing_domain  = "${var.root_domain}"

  environment_prefix = var.environment == "prod" ? "" : "${var.environment}."
  environment_platform_domain = "${local.environment_prefix}${var.platform_subdomain}.${var.root_domain}"
  environment_api_domain      = "${local.environment_prefix}${var.platform_subdomain}.${var.api_domain}"

  ecr_repository_name           = local.environment_namespace
  ecr_repository_image          = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.ecr_repository_name}:latest"

  mysql_database                = substr(replace(var.environment_name, "-", "_"), -64, -1)
  mysql_username                = local.mysql_database

  s3_bucket_name                = "${local.environment}.${var.platform_subdomain}.${var.root_domain}"
  s3_reactjs_bucket_name        = "reactjs.${local.environment_marketing_domain}"

  tags = merge(
    var.tags,
    {
      "smarter/environment"                   = local.environment
      "smarter/environment_name"              = var.environment_name
      "smarter/environment_namespace"         = local.environment_namespace
      "smarter/environment_platform_domain"   = local.environment_platform_domain
      "smarter/environment_api_domain"        = local.environment_api_domain
      "smarter/environment_marketing_domain"  = local.environment_marketing_domain
    }
  )

}
