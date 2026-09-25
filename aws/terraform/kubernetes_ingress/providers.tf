#------------------------------------------------------------------------------
# written by:   Lawrence McDaniel
#               https://lawrencemcdaniel.com
#
# date:         Feb-2026
#
# usage:        providers for the default cluster-wide traefik ingress controller
#------------------------------------------------------------------------------

data "aws_eks_cluster" "eks" {
  name = var.cluster_name
  region = var.aws_region
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
  region = var.aws_region
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
}
