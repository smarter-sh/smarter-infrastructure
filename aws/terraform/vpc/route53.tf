#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com
#
# date:   mar-2023
#
# usage:  DNS configuration for vps module
#------------------------------------------------------------------------------
data "aws_route53_zone" "root_domain" {
  name = var.root_domain
}

# -----------------------------------------------------------------------------
# services subdomain for hosting internal services (e.g. EKS cluster, RDS instance, etc.)
#
# example: services.smarter.sh
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "services_subdomain" {
  name = var.services_subdomain
  tags = local.tags
}

resource "aws_route53_record" "services_subdomain_ns" {
  zone_id = data.aws_route53_zone.root_domain.zone_id
  name    = aws_route53_zone.services_subdomain.name
  type    = "NS"
  ttl     = "86400"
  records = aws_route53_zone.services_subdomain.name_servers
}
