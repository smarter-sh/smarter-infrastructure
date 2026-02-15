#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      Smarter app infrastructure - Terraform configuration
#             for AWS Route53 DNS zones and DNS records
#------------------------------------------------------------------------------


# -----------------------------------------------------------------------------
# From Kubernetes shared infrastructure, managed by openedx_devops repo
# -----------------------------------------------------------------------------
data "kubernetes_service_v1" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "traefik"
  }
}
data "aws_elb_hosted_zone_id" "main" {}

# -----------------------------------------------------------------------------
# root Domain: smarter.sh
# this is created manually in the AWS Route53 console
# -----------------------------------------------------------------------------
data "aws_route53_zone" "root_domain" {
  name = var.root_domain
}

data "aws_route53_zone" "api_domain" {
  name = var.api_domain
}


# -----------------------------------------------------------------------------
# marketing site DNS A record
# -----------------------------------------------------------------------------
data "aws_route53_zone" "marketing_site" {
  name    = local.environment_marketing_domain
}

# -----------------------------------------------------------------------------
# environment Domain: alpha.platform.smarter.sh, beta.platform.smarter.sh, etc.
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "environment_platform_domain" {
  name = local.environment_platform_domain
  tags = local.tags
}

resource "aws_route53_record" "environment_platform_domain_ns" {
  zone_id = data.aws_route53_zone.root_domain.zone_id
  name    = local.environment_platform_domain
  type    = "NS"
  ttl     = "300"
  records = aws_route53_zone.environment_platform_domain.name_servers
}

resource "aws_route53_record" "environment_platform_domain" {
  zone_id = aws_route53_zone.environment_platform_domain.zone_id
  name    = local.environment_platform_domain
  type    = "A"
  alias {
      name = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].hostname
      zone_id = data.aws_elb_hosted_zone_id.main.id
      evaluate_target_health = true
    }
}

# -----------------------------------------------------------------------------
# environment Api Domain: alpha.api.smarter.sh, beta.api.smarter.sh, etc.
# -----------------------------------------------------------------------------
resource "aws_route53_zone" "environment_api_domain" {
  name = local.environment_api_domain
  tags = local.tags
}

resource "aws_route53_record" "environment_api_domain_ns" {
  zone_id = data.aws_route53_zone.api_domain.zone_id
  name    = local.environment_api_domain
  type    = "NS"
  ttl     = "300"
  records = aws_route53_zone.environment_api_domain.name_servers
}

resource "aws_route53_record" "environment_api_domain" {
  zone_id = aws_route53_zone.environment_api_domain.zone_id
  name    = local.environment_api_domain
  type    = "A"
  alias {
      name = data.kubernetes_service_v1.traefik.status[0].load_balancer[0].ingress[0].hostname
      zone_id = data.aws_elb_hosted_zone_id.main.id
      evaluate_target_health = true
    }
}


# -----------------------------------------------------------------------------
# AWS SES domain identity verification records
# -----------------------------------------------------------------------------
resource "aws_route53_record" "aws_ses_domain_identity" {
  zone_id = aws_route53_zone.environment_platform_domain.zone_id
  name    = "_amazonses.${local.environment_platform_domain}"
  type    = "TXT"
  ttl     = "600"
  records = [aws_ses_domain_identity.environment_platform_domain.verification_token]
}

resource "aws_route53_record" "environment_platform_domain_amazonses_dkim_record" {
  count   = 3
  zone_id = aws_route53_zone.environment_platform_domain.zone_id
  name    = "${aws_ses_domain_dkim.environment_platform_domain.dkim_tokens[count.index]}._domainkey"
  type    = "CNAME"
  ttl     = "600"
  records = ["${aws_ses_domain_dkim.environment_platform_domain.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

resource "aws_route53_record" "environment_platform_domain_amazonses_dmarc_record" {
  zone_id = aws_route53_zone.environment_platform_domain.zone_id
  name    = "_dmarc.${local.environment_platform_domain}"
  type    = "TXT"
  ttl     = "600"
  records = ["v=DMARC1;p=quarantine;rua=mailto:my_dmarc_report@${var.root_domain}"]
}
