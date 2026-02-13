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
  environment   = "prod"
  environment_name = "${local.global_vars.locals.platform_name}-${local.global_vars.locals.shared_resource_identifier}-${local.environment}"
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
    environment           = local.environment
    environment_name      = local.environment_name
  }
)
