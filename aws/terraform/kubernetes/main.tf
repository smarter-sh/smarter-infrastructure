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

  # Used by Karpenter config to determine correct partition (i.e. - `aws`, `aws-gov`, `aws-cn`, etc.)
  partition = data.aws_partition.current.partition
  tags = var.tags
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
data "aws_iam_policy_document" "kms_basic" {
  statement {
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.aws_account_id}:root"]
    }
  }
}
resource "aws_kms_key" "eks_secrets" {

  description = "${var.namespace} KMS key for EKS secrets encryption"
  deletion_window_in_days = 7 # minimum allowed by AWS for customer-managed keys
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_basic.json
}
# we need to hash the KMS key name in order to ensure general uniqueness, because
# KMS keys have a mandatory wait period of at least 7 days
# for deletions. Hence, if you ever intend to delete and recreate this key,
# in a shorter time period then you need to ensure the new key has a different name.
resource "random_id" "eks_secrets" {
  byte_length = 32
}

resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/eks/${var.namespace}-${random_id.eks_secrets.hex}"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

module "eks" {
  source                          = "terraform-aws-modules/eks/aws"
  version                         = "~> 21"
  endpoint_private_access         = true
  endpoint_public_access          = true
  create_cloudwatch_log_group     = false
  enable_irsa                     = true
  create_iam_role                 = true
  enable_cluster_creator_admin_permissions = true
  authentication_mode             = "API_AND_CONFIG_MAP"
  cloudwatch_log_group_class      = "INFREQUENT_ACCESS"

  name                            = var.namespace
  kubernetes_version              = var.kubernetes_cluster_version
  vpc_id                          = var.vpc_id
  subnet_ids                      = var.private_subnets
  control_plane_subnet_ids        = var.private_subnets

  # BUG NOTE: uncommenting this has the effective of REQUIRING KMS configuration
  # objects, regardless of the value of `eks_create_kms_key`. This is a Terraform bug.
  create_kms_key                  = var.eks_create_kms_key # default is false - use with caution
  kms_key_owners                  = var.kms_key_owners
  encryption_config               = {
    resources = ["secrets"]
    provider_key_arn = "arn:aws:kms:ca-central-1:090511222473:key/e9c77fc2-2933-4590-a82c-ebc9f7a88c73"
  } # replace with the scaffolding below if you ARE using KMS encryption.
  # encryption_config = {
  #     resources = ["secrets"]
  #     provider_key_arn = aws_kms_key.eks_secrets[0].arn
  # }

  tags = local.tags

  compute_config = {
   enabled = false
  }

  # NOTE:
  # KMS key management.
  # ---------------------------------------------------------------------------
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
  #
  # create_kms_key = var.eks_create_kms_key
  # kms_key_owners = var.kms_key_owners
  #
  # add the bastion IAM user to aws-auth.mapUsers so that
  # kubectl and k9s work from inside the bastion server by default.
  #
  # Cluster access entry
  # access_entries = {
  #   bastion = {
  #     kubernetes_groups = []
  #     principal_arn     = var.bastion_iam_arn

  #     policy_associations = {
  #       admin = {
  #         policy_arn = "arn:${local.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  #         access_scope = {
  #           type = "cluster"
  #         }
  #       }
  #     }
  #   }
  # }
  # ---------------------------------------------------------------------------


  # Required add-ons for basic cluster functionality. Avoid
  # adding unnecessary configuration details. The default settings work well
  # for most use cases.
  addons = {
      coredns                = {}
      eks-pod-identity-agent = {
        before_compute = true
      }
      kube-proxy             = {}
      vpc-cni                = {
        before_compute = true
      }
    aws-ebs-csi-driver = {
      service_account_role_arn = aws_iam_role.AmazonEKS_EBS_CSI_DriverRole.arn
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "smarter: Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0       # FIX NOTE: this is a security vulnerability.
      to_port     = 0       # Ideally this should be narrowed to the IP address of the
                            # nginx ingress controller's load balancer.
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
    smarter = {
      capacity_type     = "SPOT"
      enable_monitoring = false
      cluster_enabled_log_types = []
      min_size          = var.eks_node_group_min_size
      max_size          = var.eks_node_group_max_size
      desired_size      = var.eks_node_group_min_size
      instance_types    = var.eks_node_group_instance_types
      subnet_ids        = var.private_subnets


      node_repair_config = {
        enabled = true
        update_config = {
          max_unavailable_percentage = 33
        }
      }


      # Configure containerd to transparently redirect Docker Hub to ECR pull-through cache
      # Pods continue using docker.io/image:tag - no manifest changes needed
      pre_bootstrap_user_data = <<-EOT
        #!/bin/bash
        set -e

        # Configure containerd registry mirror for docker.io
        mkdir -p /etc/containerd/certs.d/docker.io
        cat > /etc/containerd/certs.d/docker.io/hosts.toml <<'EOF'
server = "https://registry-1.docker.io"

[host."https://${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.region}.amazonaws.com/docker-hub"]
  capabilities = ["pull", "resolve"]

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
EOF
      EOT

      iam_role_additional_policies = {
        AmazonEKSWorkerNodePolicy         = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
        AmazonEKS_CNI_Policy              = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

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
        { Name = "eks-${var.shared_resource_identifier}-smarter" },
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

  tags = local.tags
}

# we need to hash the secret name in order to ensure general uniqueness, because
# AWS Secrets Manager passwords have a mandatory wait period of at least 7 days
# for deletions. Hence, if you ever intend to delete and recreate this secret,
# in a shorter time period then you need to ensure the new secret has a different name.
resource "random_id" "dockerhub_credentials" {
  byte_length = 32
}

resource "aws_secretsmanager_secret" "dockerhub_credentials" {
  name        = "ecr-pullthroughcache/docker-hub-${var.namespace}/${random_id.dockerhub_credentials.hex}"
  description = "Docker Hub credentials for ECR pull-through cache"

  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "dockerhub_credentials" {
  secret_id = aws_secretsmanager_secret.dockerhub_credentials.id
  secret_string = jsonencode({
    username    = local.docker_username
    accessToken = local.docker_pat
  })
}

resource "aws_ecr_pull_through_cache_rule" "dockerhub" {
  ecr_repository_prefix = "${var.namespace}-docker-hub"
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
  name        = "eks-route53-cert-manager-${var.namespace}"
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


resource "kubernetes_namespace_v1" "namespace-shared" {
  metadata {
    name = var.namespace
  }
  depends_on = [module.eks]
}
