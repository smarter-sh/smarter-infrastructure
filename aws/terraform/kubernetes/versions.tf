#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2023
#
# usage: create an EKS cluster
#------------------------------------------------------------------------------
terraform {
  required_version = "~> 1.5"

  required_providers {
    local = "~> 2.4"
    random = {
      source  = "hashicorp/random"
    }

    aws = {
      source  = "hashicorp/aws"
    }
    helm = {
      source  = "hashicorp/helm"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
  }
}
