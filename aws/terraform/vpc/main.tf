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
  tags = merge(local.tags, {"Name" = "${var.name}-s3"})
}

resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, {"Name" = "${var.name}-bastion-sg"})
}


resource "aws_key_pair" "bastion" {
  key_name   = "bastion"
  public_key = file(local.bastion_public_key_path)

  tags = merge(local.tags, {"Name" = "bastion"})
}
resource "aws_instance" "bastion" {
  # ami           = data.aws_ami.amazon_linux.id
  ami           = "ami-0dd624c7f457c3741"
  instance_type = "t3.micro"
  subnet_id     = module.vpc.public_subnets[0]
  key_name      = "bastion"
  iam_instance_profile = aws_iam_instance_profile.ssm.name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  tags = merge(local.tags, {"Name" = "bastion"})

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
    delete_on_termination = true
    tags = merge(local.tags, {"Name" = "bastion-root"})
  }

  lifecycle {
    prevent_destroy = true
  }
}


resource "aws_eip" "bastion" {
  region = var.aws_region
  instance = aws_instance.bastion.id
  tags = merge({
    Name = "bastion"
    "smarter/cluster_name" = var.cluster_name
  }, local.tags)
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
