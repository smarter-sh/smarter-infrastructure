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
  bastion_public_key_path = var.bastion_public_key_path
  tags = merge(
    var.tags,
    {
      "smarter" = "true"
    }
  )

}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
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
# create VPC endpoints for ECR and STS so that our backend resources can access
# these services without going through the internet.
#
# see https://aws.amazon.com/es/blogs/containers/using-vpc-endpoint-policies-to-control-amazon-ecr-access/
# for more info on ECR endpoints.
#
# usage:
# $ aws ssm start-session --target <instance-id>
# $ aws eks update-kubeconfig --region <region> --name <cluster-name>
# -----------------------------------------------------------------------------
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.private_subnets
  tags = local.tags
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.private_subnets
  tags = local.tags
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.sts"
  vpc_endpoint_type = "Interface"
  subnet_ids        = module.vpc.private_subnets
  tags = local.tags
}

resource "aws_security_group" "admin" {
  name        = "${var.name}-admin-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}


resource "aws_key_pair" "bastion" {
  key_name   = "bastion"
  public_key = file(local.bastion_public_key_path)

  tags = local.tags
}
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = "bastion"
  iam_instance_profile = aws_iam_instance_profile.ssm.name
  vpc_security_group_ids = [aws_security_group.admin.id]
  tags = merge(local.tags, {"Name" = "bastion"})
}

resource "aws_eip" "bastion" {
  region = var.aws_region
  instance = aws_instance.bastion.id
  tags = local.tags
}

resource "aws_iam_role" "ssm" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  role = aws_iam_role.ssm.name
  tags = local.tags
}
