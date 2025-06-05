resource "kubernetes_manifest" "platform_ingress" {
  manifest = yamldecode(templatefile("${path.module}/templates/ingress.yaml.tpl", {
    cluster_issuer        = local.environment_platform_domain
    domain                = local.environment_platform_domain
    environment_namespace = local.environment_namespace
    service_name          = var.shared_resource_identifier
    platform_domain       = "${var.platform_subdomain}.${var.root_domain}"
    api_domain            = "${var.api_subdomain}.${var.root_domain}"
  }))

  depends_on = [
    data.aws_route53_zone.environment_platform_domain
  ]
}

resource "kubernetes_manifest" "api_ingress" {
  manifest = yamldecode(templatefile("${path.module}/templates/ingress.yaml.tpl", {
    cluster_issuer        = local.environment_api_domain
    domain                = local.environment_api_domain
    environment_namespace = local.environment_namespace
    service_name          = var.shared_resource_identifier
    platform_domain       = "${var.platform_subdomain}.${var.root_domain}"
    api_domain            = "${var.api_subdomain}.${var.root_domain}"
  }))

  depends_on = [
    data.aws_route53_zone.api
  ]
}
