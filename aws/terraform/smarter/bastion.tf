#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      create Route53 record for the EC2 bastion host, which is used
#             for SSH access to the EKS cluster nodes.
#------------------------------------------------------------------------------


data "aws_eip" "bastion" {
tags = {
    Name = "bastion"
  }
}

resource "aws_route53_record" "bastion" {
  zone_id = aws_route53_zone.environment_platform_domain.zone_id
  name    = "bastion.${local.environment_platform_domain}"
  type    = "A"
  records = [data.aws_eip.bastion.public_ip]
  ttl     = "600"
}
