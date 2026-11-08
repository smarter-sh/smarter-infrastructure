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
# at https://github.com/smarter-sh/smarter/blob/main/helm/charts/smarter/templates/service-api.yaml
#
# More specifically, the 'service_name' of this template needs to match the name of the Service that the
# Helm chart creates for the api: <appName>-api, e.g. smarter-api. The chart renamed it from <appName>, and
# runs both Services while app.legacyName.enabled is true, so that this module moves to the new name first,
# in an environment that already runs a release with both. Applied before that, the ingresses name a
# Service that doesn't exist, and the environment answers 404.
locals {
  api_service_name = "${local.platform_name}-api"
}

resource "kubernetes_manifest" "platform_ingress" {
  manifest = yamldecode(templatefile("${path.module}/templates/ingress.yaml.tpl", {
    app_name              = local.platform_name
    service_name          = local.api_service_name
    cluster_issuer        = local.environment_platform_domain
    domain                = local.environment_platform_domain
    environment_namespace = local.environment_namespace
    platform_domain       = "${var.platform_subdomain}.${var.root_domain}"
    platform_api_domain   = var.platform_api_domain
  }))

  # Terraform owns this ingress. A hand-made change, e.g. a kubectl patch in an incident, takes ownership
  # of the fields it touched, and the next apply would fail with a field manager conflict instead of
  # restoring them.
  field_manager {
    force_conflicts = true
  }

  depends_on = [
    kubernetes_namespace_v1.smarter,
    aws_route53_zone.environment_platform_domain
  ]
}

resource "kubernetes_manifest" "api_ingress" {
  manifest = yamldecode(templatefile("${path.module}/templates/ingress.yaml.tpl", {
    app_name              = local.platform_name
    service_name          = local.api_service_name
    cluster_issuer        = local.environment_api_domain
    domain                = local.environment_api_domain
    environment_namespace = local.environment_namespace
    platform_domain       = "${var.platform_subdomain}.${var.root_domain}"
    platform_api_domain   = var.platform_api_domain
  }))

  # See platform_ingress.
  field_manager {
    force_conflicts = true
  }

  depends_on = [
    aws_route53_zone.environment_api_domain
  ]
}

resource "kubernetes_manifest" "traefik-middleware-cors" {
  manifest = yamldecode(templatefile("${path.module}/templates/traefik-middleware-cors.yaml.tpl", {
    app_name              = local.platform_name
    environment_namespace = local.environment_namespace
    platform_domain       = local.environment_platform_domain
    platform_api_domain   = local.environment_api_domain
  }))

  depends_on = [
    kubernetes_namespace_v1.smarter,
    aws_route53_zone.environment_platform_domain
  ]
}

resource "kubernetes_manifest" "traefik-middleware-http-redirect" {
  manifest = yamldecode(templatefile("${path.module}/templates/traefik-middleware-http-redirect.yaml.tpl", {
    app_name              = local.platform_name
    environment_namespace = local.environment_namespace
    platform_domain       = local.environment_platform_domain
    platform_api_domain   = local.environment_api_domain
  }))

  depends_on = [
    kubernetes_namespace_v1.smarter,
    aws_route53_zone.environment_platform_domain
  ]
}


resource "kubernetes_manifest" "traefik-service-sessions" {
  manifest = yamldecode(templatefile("${path.module}/templates/traefik-service-sessions.yaml.tpl", {
    app_name              = local.platform_name
    service_name          = local.api_service_name
    environment_namespace = local.environment_namespace
  }))

  depends_on = [
    kubernetes_namespace_v1.smarter,
    aws_route53_zone.environment_platform_domain
  ]
}
