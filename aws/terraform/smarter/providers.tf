#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      Smarter app infrastructure - Terraform providers for this
#             Smarter environment.
#------------------------------------------------------------------------------

data "aws_eks_cluster" "eks" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
}

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
    null = {
      source  = "hashicorp/null"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.0"
    }
  }
}
provider "kubernetes" {

  config_path = "~/.kube/config"
  config_context = "smarter-ubc-ca-202602121853"
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}
