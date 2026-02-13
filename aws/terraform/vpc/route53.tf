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

# -----------------------------------------------------------------------------
# api subdomain for hosting public API endpoints
#
# example: api.smarter.sh
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "api_domain" {
  name = "${var.api_domain}.${var.root_domain}"
  tags = local.tags
}

resource "aws_route53_record" "api_domain_ns" {
  zone_id = data.aws_route53_zone.root_domain.zone_id
  name    = aws_route53_zone.api_domain.name
  type    = "NS"
  ttl     = "300"
  records = aws_route53_zone.api_domain.name_servers
}
