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
