#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Aug-2023
#
# usage: all providers for Kubernetes and its sub-systems. The general strategy
#        is to manage authentications via aws cli where possible.
#
#        another alternative for each of the providers would be to rely on
#        the local kubeconfig file.
#------------------------------------------------------------------------------

data "aws_eks_cluster" "eks" {
  name = var.cluster_name
  region = var.aws_region
}

data "aws_eks_cluster_auth" "eks" {
  name = var.cluster_name
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}


provider "helm" {
}
