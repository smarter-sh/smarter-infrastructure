#------------------------------------------------------------------------------
# written by:   Lawrence McDaniel
#               https://lawrencemcdaniel.com
#
# date:         Feb-2026
#
# usage:        version pins for the default cluster-wide traefik ingress controller
#------------------------------------------------------------------------------
terraform {

  required_providers {
    local = ">= 2.4"
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
