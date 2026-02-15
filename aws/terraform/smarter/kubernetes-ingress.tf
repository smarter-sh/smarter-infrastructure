#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      Smarter app infrastructure - create Kubernetes ingress resources
#             for the platform and API domains. These ingress resources will be
#             used to route traffic to the Smarter app service.
#------------------------------------------------------------------------------


# The Kubernetes ingress needs to handshake with the Helm chart that deploys
# The Smarter application pod(s) and service. See the Helm chart
# at https://github.com/smarter-sh/smarter/blob/main/helm/charts/smarter/templates/deployment_app.yaml#L10
#
# More specifically, the 'service_name' of this template needs to match the deployment app's metadata.app
# field.
resource "kubernetes_manifest" "platform_ingress" {
  manifest = yamldecode(templatefile("${path.module}/templates/ingress.yaml.tpl", {
    cluster_issuer        = local.environment_platform_domain
    domain                = local.environment_platform_domain
    environment_namespace = local.environment_namespace
    service_name          = "smarter"
    platform_domain       = "${var.platform_subdomain}.${var.root_domain}"
    api_domain            = var.api_domain
  }))

  depends_on = [
    aws_route53_zone.environment_platform_domain
  ]
}

resource "kubernetes_manifest" "api_ingress" {
  manifest = yamldecode(templatefile("${path.module}/templates/ingress.yaml.tpl", {
    cluster_issuer        = local.environment_api_domain
    domain                = local.environment_api_domain
    environment_namespace = local.environment_namespace
    service_name          = "smarter"
    platform_domain       = "${var.platform_subdomain}.${var.root_domain}"
    api_domain            = var.api_domain
  }))

  depends_on = [
    aws_route53_zone.environment_api_domain
  ]
}

resource "kubernetes_manifest" "traefik-middleware-cors" {
  manifest = yamldecode(templatefile("${path.module}/templates/traefik-middleware-cors.yaml.tpl", {
    environment_namespace = local.environment_namespace
    platform_domain       = local.environment_platform_domain
    api_domain            = local.environment_api_domain
  }))

  depends_on = [
    aws_route53_zone.environment_platform_domain
  ]
}

resource "kubernetes_manifest" "traefik-middleware-http-redirect" {
  manifest = yamldecode(templatefile("${path.module}/templates/traefik-middleware-http-redirect.yaml.tpl", {
    environment_namespace = local.environment_namespace
    platform_domain       = local.environment_platform_domain
    api_domain            = local.environment_api_domain
  }))

  depends_on = [
    aws_route53_zone.environment_platform_domain
  ]
}


resource "kubernetes_manifest" "traefik-service-sessions" {
  manifest = yamldecode(templatefile("${path.module}/templates/traefik-service-sessions.yaml.tpl", {
    environment_namespace = local.environment_namespace
  }))

  depends_on = [
    aws_route53_zone.environment_platform_domain
  ]
}
