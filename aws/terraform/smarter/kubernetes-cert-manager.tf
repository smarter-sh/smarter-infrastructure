
resource "kubernetes_manifest" "issuer_platform" {
  manifest = yamldecode(templatefile("${path.module}/templates/issuer.yml.tpl", {
    root_domain    = var.root_domain
    environment    = local.environment
    domain         = local.environment_platform_domain
    namespace      = "cert-manager"
    aws_region     = var.aws_region
    hosted_zone_id = data.aws_route53_zone.environment_platform_domain.zone_id
  }))

  depends_on = [
    kubernetes_namespace.smarter,
    kubernetes_manifest.platform_ingress,
  ]
}

resource "kubernetes_manifest" "issuer_api" {
  manifest = yamldecode(templatefile("${path.module}/templates/issuer.yml.tpl", {
    root_domain    = var.root_domain
    environment    = local.environment
    domain         = local.environment_api_domain
    namespace      = "cert-manager"
    aws_region     = var.aws_region
    hosted_zone_id = data.aws_route53_zone.api.zone_id
  }))

  depends_on = [
    kubernetes_namespace.smarter,
    kubernetes_manifest.platform_ingress,
  ]
}

