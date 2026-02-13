
locals {
  issuer_platform_manifest = yamldecode(templatefile("${path.module}/templates/issuer.yml.tpl", {
    root_domain    = var.root_domain
    domain         = local.environment_platform_domain
    namespace      = local.environment_namespace
    aws_region     = var.aws_region
    hosted_zone_id = aws_route53_zone.environment_platform_domain.zone_id
  }))

  issuer_api_manifest = yamldecode(templatefile("${path.module}/templates/issuer.yml.tpl", {
    root_domain    = var.root_domain
    domain         = local.environment_api_domain
    namespace      = local.environment_namespace
    aws_region     = var.aws_region
    hosted_zone_id = aws_route53_zone.environment_api_domain.zone_id
  }))
}
# resource "kubernetes_manifest" "issuer_platform" {
#   manifest = local.issuer_platform_manifest

#   depends_on = [
#     kubernetes_namespace_v1.smarter,
#     aws_route53_zone.environment_platform_domain
#   ]
# }

# resource "kubernetes_manifest" "issuer_api" {
#   manifest = local.issuer_api_manifest
#   depends_on = [
#     kubernetes_namespace_v1.smarter,
#     aws_route53_zone.environment_api_domain
#   ]
# }
