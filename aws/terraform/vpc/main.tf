#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com
#
# date: mar-2023
#
# usage: create a VPC to contain all Open edX backend resources.
#        this VPC is configured to generally use all AWS defaults.
#        Thus, you should get the same configuration here that you'd
#        get by creating a new VPC from the AWS Console.
#
#        There are a LOT of options in this module.
#        see https://registry.terraform.io/terraform/terraform-aws-modules/vpc/aws/latest
#------------------------------------------------------------------------------
locals {
  tags = merge(
    var.tags,
    {
      "smarter" = "true"
    }
  )

}

module "vpc" {
  source                 = "terraform-aws-modules/vpc/aws"
  version                = "~> 6.0"
  create_vpc             = true
  name                   = var.name
  cidr                   = var.cidr
  azs                    = var.azs
  public_subnets         = var.public_subnets
  private_subnets        = var.private_subnets
  intra_subnets          = var.intra_subnets
  intra_subnet_tags      = var.intra_subnet_tags
  database_subnets       = var.database_subnets
  elasticache_subnets    = var.elasticache_subnets
  enable_ipv6            = var.enable_ipv6
  enable_dns_hostnames   = var.enable_dns_hostnames
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az
  public_subnet_tags     = var.public_subnet_tags
  private_subnet_tags    = var.private_subnet_tags

  tags = local.tags
}

# -----------------------------------------------------------------------------
# S3 gateway endpoint. Gateway endpoints are free, and keep S3 traffic
# (including ECR image layer pulls, which are served from S3) off of the
# NAT Gateway, avoiding its $0.05/GB data processing charge.
#
# note: ECR and STS interface endpoints were removed because they are billed
# per AZ-hour (3 endpoints x 3 AZs = ~$74/month), which far exceeded the NAT
# data processing charges they could offset.
# -----------------------------------------------------------------------------
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(
    module.vpc.private_route_table_ids,
    module.vpc.intra_route_table_ids,
  )
  tags = merge(local.tags, { "Name" = "${var.name}-s3" })
}
