#------------------------------------------------------------------------------
# written by:   Lawrence McDaniel
#               https://lawrencemcdaniel.com
#
# date:         Feb-2026
#
# usage:        create DNS records for the default cluster-wide traefik ingress controller
#------------------------------------------------------------------------------
data "aws_route53_zone" "services_subdomain" {
  name = var.services_subdomain
}

data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "traefik"
  }

  depends_on = [
    helm_release.traefik
  ]
}

# -------------------------------------------------------------------------------------
# setup DNS for root domain
# -------------------------------------------------------------------------------------
data "aws_route53_zone" "root_domain" {
  name = var.root_domain
}
