locals {
  acme_challenge_record_name = "_acme-challenge.${local.environment_platform_domain}"
}

# route53 environment-specific dns record
data "kubernetes_service" "ingress_nginx_controller" {
  metadata {
    name      = "common-ingress-nginx-controller"
    namespace = "kube-system"
  }
}
data "aws_elb_hosted_zone_id" "main" {}
data "aws_route53_zone" "root_domain" {
  name = var.root_domain
}

data "aws_route53_zone" "api" {
  name    = local.environment_api_domain
}

data "aws_route53_zone" "environment_platform_domain" {
  name    = local.environment_platform_domain
}

# -----------------------------------------------------------------------------
# environment Domain: alpha.platform.smarter.sh, beta.platform.smarter.sh, etc.
# -----------------------------------------------------------------------------
resource "aws_route53_record" "aws_ses_domain_identity" {
  zone_id = data.aws_route53_zone.environment_platform_domain.zone_id
  name    = "_amazonses.${local.environment_platform_domain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.environment_platform_domain.verification_token]
}

resource "aws_route53_record" "environment_platform_domain_amazonses_dkim_record" {
  count   = 3
  zone_id = data.aws_route53_zone.environment_platform_domain.zone_id
  name    = "${aws_ses_domain_dkim.environment_platform_domain.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.environment_platform_domain.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "environment_platform_domain_amazonses_dmarc_record" {
  zone_id = data.aws_route53_zone.environment_platform_domain.zone_id
  name    = "_dmarc.${local.environment_platform_domain}"
  type    = "TXT"
  ttl     = "600"
  records = ["v=DMARC1;p=quarantine;rua=mailto:my_dmarc_report@${var.root_domain}"]
}

