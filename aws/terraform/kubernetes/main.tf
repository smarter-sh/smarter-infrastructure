#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date: Mar-2022
#
# usage: create an EKS cluster with one managed node group for EC2
#        plus a Fargate profile for serverless computing.
#
# Technical documentation:
# - https://docs.aws.amazon.com/kubernetes
# - https://registry.terraform.io/terraform/terraform-aws-modules/eks/aws/
# - https://repost.aws/knowledge-center/execute-user-data-ec2
#------------------------------------------------------------------------------
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Load Docker Hub credentials from .env file
locals {
  env_file = try(file("${path.module}/../../../../.env"), "")
  env_vars = { for line in split("\n", local.env_file) :
    split("=", line)[0] => split("=", line)[1]
    if length(regexall("^[A-Z_]+=.+", line)) > 0
  }
  docker_username = lookup(local.env_vars, "DOCKER_USERNAME", "")
  docker_pat      = lookup(local.env_vars, "DOCKER_PAT", "")
}

locals {
  # Used by Karpenter config to determine correct partition (i.e. - `aws`, `aws-gov`, `aws-cn`, etc.)
  partition = data.aws_partition.current.partition


  tags = merge(
    var.tags,
    {
      "smarter"  = "true",
    }
  )

  # complete list of instance types with
  #   - x86_64 / amd64 cpu architecture (and ARM64 for t4g)
  #   - Memory >= 8 GiB
  #   - vCPU == 2
  amd64_instance_types = [
        "t3.xlarge",
        "t3.large",
        "m5.large",
        "m5.xlarge",
        "c5.large",
        "c5.xlarge",
        "t3.2xlarge",
  ]
  graviton_instance_types = [
        "t4g.large",
        "c6g.large",
        "m6g.large",
        "r6g.large",
        "c7g.large",
        "m7g.large",
        "r7g.large",
        "c8g.large",
        "r8g.large",
        "m8g.large"
  ]
  instance_types_graviton_preferred = local.graviton_instance_types

}

# NOTE:
# Use **ONLY** if you want to enable Kubernetes secrets encryption with a
# customer-managed KMS key. This has irreversible consequences and should
# be used with caution. If you enable this, you will need to uncomment
# the `encryption_config` block in the `module "eks"` configuration below,
# and the `aws_kms_key` resource definition. If you do not enable this,
# Kubernetes secrets will be encrypted with an AWS-managed KMS key by
# default, which is sufficient for most use cases.
#
# resource "aws_kms_key" "eks_secrets" {
#   description = "KMS key for EKS secrets encryption"
#   deletion_window_in_days = 10
#   enable_key_rotation     = true
#   policy                  = data.aws_iam_policy_document.kms_basic.json
# }

# data "aws_iam_policy_document" "kms_basic" {
#   statement {
#     actions   = ["kms:*"]
#     resources = ["*"]
#     principals {
#       type        = "AWS"
#       identifiers = ["arn:aws:iam::090511222473:root"]
#     }
#   }
# }




module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "~> 21"
  name                            = var.namespace
  kubernetes_version              = var.kubernetes_cluster_version
  endpoint_private_access         = true
  endpoint_public_access          = true
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.private_subnet_ids
  create_cloudwatch_log_group     = false
  enable_irsa                     = true
  authentication_mode             = "API_AND_CONFIG_MAP"
  cloudwatch_log_group_class      = "INFREQUENT_ACCESS"

  # NOTE:
  # larger organizations might want to change these two settings
  # in order to further restrict which IAM users have access to
  # the AWS EKS Kubernetes Secrets. Note that at cluster creation,
  # this key is benign since Kubernetes secrets encryption
  # is not enabled by default.
  #
  # AWS EKS KMS console: https://us-east-2.console.aws.amazon.com/kms/home
  #
  # audit your AWS EKS KMS key access by running:
  # aws kms get-key-policy --key-id ADD-YOUR-KEY-ID-HERE --region us-east-2 --policy-name default --output text

  # create_kms_key = var.eks_create_kms_key
  # kms_key_owners = var.kms_key_owners

  # encryption_config = {
  #   resources = ["secrets"]
  #   provider = {
  #     key_arn = aws_kms_key.eks_secrets.arn
  #   }
  # }

  # add the bastion IAM user to aws-auth.mapUsers so that
  # kubectl and k9s work from inside the bastion server by default.
  create_iam_role = true

  # Cluster access entry
  # enable_cluster_creator_admin_permissions = true
  access_entries = {
    bastion = {
      kubernetes_groups = []
      principal_arn     = var.bastion_iam_arn

      policy_associations = {
        admin = {
          policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = merge(
    local.tags,
    {
      "smarter"  = "true",
    }
  )

  addons = {
    # aws-eks-pod-identity-agent = {
    # }
    vpc-cni = {
      service_account_role_arn = aws_iam_role.AmazonEKS_VPC_CNI_Role.arn
      configuration_values = jsonencode({
        env = {
          WARM_IP_TARGET      = "2"
          MINIMUM_IP_TARGET   = "5"
        }
      })
    }
    coredns = {
      service_account_role_arn = aws_iam_role.AmazonEKS_CoreDNS_Role.arn
    }
    kube-proxy = {
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.AmazonEKS_EBS_CSI_DriverRole.arn
    }

  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "smarter: Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      cidr_blocks = [
        "172.16.0.0/12",
        "192.168.0.0/16",
      ]
    }
    port_8443 = {
      description = "smarter: open port 8443 to vpc"
      protocol    = "-1"
      from_port   = 8443
      to_port     = 8443
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "smarter: Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }


  eks_managed_node_groups = {





    amd64 = {
      capacity_type     = "SPOT"
      enable_monitoring = false
      cluster_enabled_log_types = []
      min_size          = 2
      max_size          = 10


      node_repair_config = {
        enabled = true
        update_config = {
          max_unavailable_percentage = 33
        }
      }

      # mcdaniel nov-2025
      # leaving this as AMD64 chipsets until all openedx instances are removed from the cluster.
      # ami_type         = "AL2023_ARM_64_STANDARD"
      instance_types    = [
            "t3.large",
            "m5.large",
            "c5.large",
      ]
      subnet_ids        = [element(var.private_subnet_ids, 0)]

      # Configure containerd to transparently redirect Docker Hub to ECR pull-through cache
      # Pods continue using docker.io/image:tag - no manifest changes needed
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        set -e

        # Configure containerd registry mirror for docker.io
        mkdir -p /etc/containerd/certs.d/docker.io
        cat > /etc/containerd/certs.d/docker.io/hosts.toml <<'EOF'
server = "https://registry-1.docker.io"

[host."https://${data.aws_caller_identity.current.aws_account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/docker-hub"]
  capabilities = ["pull", "resolve"]

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
EOF
      EOT

      iam_role_additional_policies = {
        # Required by Karpenter
        AmazonSSMManagedInstanceCore = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"

        # Required by EBS CSI Add-on
        AmazonEBSCSIDriverPolicy = data.aws_iam_policy.AmazonEBSCSIDriverPolicy.arn

        # Required for ECR pull-through cache
        ECRPullThroughCache = aws_iam_policy.ecr_pull_through_cache.arn
      }


      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_type           = "gp3"
            volume_size           = 150
            delete_on_termination = true
          }
        }
      }

      tags = merge(
        local.tags,
        # Tag node group resources for Karpenter auto-discovery
        # NOTE - if creating multiple security groups with this module, only tag the
        # security group that Karpenter should utilize with the following tag
        { Name = "eks-${var.shared_resource_identifier}-arm64" },
      )
    }
  }
}

#==============================================================================
#                             SUPPORTING RESOURCES
#==============================================================================

#==============================================================================
# AWS ECR Pull-Through Cache Policy
#==============================================================================
resource "aws_iam_policy" "ecr_pull_through_cache" {
  name        = "${var.namespace}-ecr-pull-through-cache"
  description = "Allow EKS nodes to pull from ECR pull-through cache"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(
    local.tags,
    {
      "smarter"  = "true"
    }
  )
}

resource "aws_secretsmanager_secret" "dockerhub_credentials" {
  name        = "ecr-pullthroughcache/docker-hub"
  description = "Docker Hub credentials for ECR pull-through cache"

  tags = merge(
    local.tags,
    {
      "smarter"  = "true"
    }
  )
}

resource "aws_secretsmanager_secret_version" "dockerhub_credentials" {
  secret_id = aws_secretsmanager_secret.dockerhub_credentials.id
  secret_string = jsonencode({
    username    = local.docker_username
    accessToken = local.docker_pat
  })
}

resource "aws_ecr_pull_through_cache_rule" "dockerhub" {
  ecr_repository_prefix = "docker-hub"
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = aws_secretsmanager_secret.dockerhub_credentials.arn

  #depends_on = [aws_secretsmanager_secret_version.dockerhub_credentials]
}


# data "aws_ami" "ubuntu" {
#   most_recent = true
#   owners      = ["099720109477"] # Canonical
#   filter {
#     name = "name"
#     # was https://aws.amazon.com/marketplace/server/procurement?productId=prod-lg73jq6vy35h2
#     # now https://aws.amazon.com/marketplace/pp/prodview-gktonp3vixhqo?sr=0-13&ref_=beagle&applicationId=AWSMPContessa
#     values = ["ubuntu-eks-pro/k8s_1.33/images/hvm-ssd/ubuntu-jammy-22.04-amd64*"]
#   }
# }

#==============================================================================
# Certificate Manager Route53 Update Policy
#==============================================================================
resource "aws_iam_policy" "MANUAL_route53_update_records" {
  name        = "eks-route53-cert-manager"
  description = "Allow cert-manager on EKS nodes to manage Route53 DNS records"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange"
        ]
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_security_group" "worker_group_mgmt" {
  name_prefix = "${var.namespace}-eks_hosting_group_mgmt"
  description = "smarter: Ingress CLB worker group management"
  vpc_id      = var.vpc_id

  ingress {
    description = "smarter: Ingress CLB"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
    ]
  }

  tags = merge(
    local.tags,
    { Name = "eks-${var.shared_resource_identifier}-worker_group_mgmt" },
    {
      "smarter"  = "true"
    }
  )
}

resource "aws_security_group" "all_worker_mgmt" {
  name_prefix = "${var.namespace}-eks_all_worker_management"
  description = "smarter: Ingress CLB worker management"
  vpc_id      = var.vpc_id

  ingress {
    description = "smarter: Ingress CLB"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }

  tags = merge(
    local.tags,
    { Name = "eks-${var.shared_resource_identifier}-all_worker_mgmt" },
    {
      "smarter"  = "true"
    }
  )
}


resource "kubernetes_namespace_v1" "namespace-shared" {
  metadata {
    name = var.namespace
  }
  #depends_on = [module.eks]
}

