#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com
#
# date:   mar-2023
#
# usage:  version pints for vps module
#------------------------------------------------------------------------------
terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    local = {
      source  = "hashicorp/local"
    }
  }
}
