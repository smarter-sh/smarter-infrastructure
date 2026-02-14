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

data "aws_elb_hosted_zone_id" "main" {}

# -------------------------------------------------------------------------------------
# setup DNS for root domain
# -------------------------------------------------------------------------------------
data "aws_route53_zone" "root_domain" {
  name = var.root_domain
}

# -------------------------------------------------------------------------------------
# setup DNS for admin subdomain
# -------------------------------------------------------------------------------------

resource "aws_route53_record" "admin_naked" {
  zone_id = data.aws_route53_zone.services_subdomain.id
  name    = var.services_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.traefik.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "admin_wildcard" {
  zone_id = data.aws_route53_zone.services_subdomain.id
  name    = "*.${var.services_subdomain}"
  type    = "A"

  alias {
    name                   = data.kubernetes_service_v1.traefik.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = data.aws_elb_hosted_zone_id.main.id
    evaluate_target_health = true
  }
}
