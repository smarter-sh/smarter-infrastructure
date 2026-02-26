#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://www.linkedin.com/in/lawrencemcdaniel/
#
# date: Feb-2024
#
# usage: create a new smarter environment
#------------------------------------------------------------------------------
locals {
  global_vars   = read_terragrunt_config(find_in_parent_folders("global.hcl"))
  stack_vars    = read_terragrunt_config("../../stack/stack.hcl")

  environment                = "prod"
  platform_subdomain         = "local"
  shared_resource_identifier = local.platform_subdomain
  platform_domain            = "${local.platform_subdomain}.${local.global_vars.locals.root_domain}"
  platform_api_domain        = "api.${local.platform_subdomain}.${local.global_vars.locals.root_domain}"
  shared_resource_namespace  = "${local.shared_resource_identifier}-${local.global_vars.locals.aws_region}-${local.shared_resource_identifier}"
  environment_name           = "${local.global_vars.locals.platform_name}-${local.shared_resource_identifier}"

  tags = merge(
    local.global_vars.locals.tags,
    {
    "smarter/platform_subdomain" = local.platform_subdomain,
  })

}

# Terragrunt will copy the Terraform configurations specified by the source parameter, along with any files in the
# working directory, into a temporary folder, and execute your Terraform commands in that folder.

terraform {
  source = "../../terraform/smarter"
}

# Include all settings from the root terragrunt.hcl file
include {
  path = find_in_parent_folders()
}

# These are the variables we have to pass in to use the module specified in the terragrunt configuration above
inputs = merge(
  local.global_vars.locals,
  local.stack_vars.locals,
  {
  environment                = local.environment
  platform_subdomain         = local.platform_subdomain
  shared_resource_identifier = local.shared_resource_identifier
  platform_domain            = local.platform_domain
  platform_api_domain        = local.platform_api_domain
  shared_resource_namespace  = local.shared_resource_namespace
  environment_name           = local.environment_name
  tags                       = local.tags
  }
)
