#------------------------------------------------------------------------------
# written by:   Lawrence McDaniel
#               https://lawrencemcdaniel.com
#
# date:         oct-2022
#
# usage:        create a default cluster-wide traefik ingress controller
#               to be used by any ingress anywhere in the cluster
#               that does not explicitly specify a different class.
#
# see:          https://github.com/kubernetes/ingress-nginx/issues/5593
#               https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class
#
# helm reference:
#   brew install helm
#
#   helm repo add traefik https://traefik.github.io/charts
#   helm repo update
#   helm show all traefik/traefik
#   helm show values traefik/traefik
#------------------------------------------------------------------------------
locals {
  templatefile_traefik_values = templatefile("${path.module}/templates/traefik-values.yaml.tpl", {})
  namespace = "traefik"
  tags = merge(
    var.tags,
    {
      "smarter"    = "true"
    }
  )
}

resource "helm_release" "traefik_crds" {
  name       = "traefik-crds"
  chart      = "traefik-crds"
  repository = "https://traefik.github.io/charts"
  namespace  = local.namespace
  create_namespace = true
}

resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = local.namespace
  create_namespace = true
  chart      = "traefik"
  repository = "https://traefik.github.io/charts"

  values = [
    local.templatefile_traefik_values
  ]

  depends_on = [ helm_release.traefik_crds ]
}
