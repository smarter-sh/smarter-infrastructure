#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Aug-2023
#
# usage: installs Descheduler for Kubernetes
# see: https://github.com/kubernetes-sigs/descheduler/blob/master/charts/descheduler/README.md
#      https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
#
# requirements: you must initialize a local helm repo in order to run
# this mdoule.
#
#   brew install helm
#   helm repo add descheduler https://kubernetes-sigs.github.io/descheduler/
#   helm repo update
#   helm search repo descheduler
#   helm show values descheduler/descheduler
#
# NOTE: run `helm repo update` prior to running this
#       Terraform module.
#-----------------------------------------------------------
locals {
  descheduler_namespace = "descheduler"

  templatefile_descheduler_values = templatefile("${path.module}/yml/descheduler-values.yaml", {})

  tags = merge(
    var.tags,
    {
      "smarter"    = "true"
    }
  )
}



resource "helm_release" "descheduler" {
  namespace        = local.descheduler_namespace
  create_namespace = true

  name       = "descheduler"
  repository = "https://kubernetes-sigs.github.io/descheduler/"
  chart      = "descheduler"

  version = "~> 0.27"

  values = [
    local.templatefile_descheduler_values
  ]

}

#------------------------------------------------------------------------------
#                           SUPPORTING RESOURCES
#------------------------------------------------------------------------------

