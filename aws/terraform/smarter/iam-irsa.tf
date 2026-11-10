#------------------------------------------------------------------------------
# usage:      Smarter app infrastructure - the IAM roles of this environment's
#             pods, with IAM Roles for Service Accounts (IRSA).
#
# The Smarter Helm chart runs the app, the Celery workers, beat and the init
# job as the ServiceAccount "smarter", and the MariaDB backup CronJob as
# "smarter-backup". The deploy annotates each with its role's ARN
# (serviceAccount.awsRoleArn, databaseScheduledBackup.awsRoleArn), and the EKS
# pod identity webhook hands the pods short-lived credentials for it. No AWS
# access key is stored in the pods.
#
# Each environment has its own roles, so alpha can't touch prod's buckets or
# node groups. Two kinds of resource can't be narrowed to an environment:
#
# - Route53: Smarter creates a hosted zone for every custom domain, whose id
#   isn't known in advance, so the zone actions are on hostedzone/*.
# - ACM: Smarter requests certificates without tags, so they can't be told
#   apart by a condition.
#------------------------------------------------------------------------------

locals {
  # Smarter's own name for the environment, smarter_settings.environment. The
  # local environment's Terraform environment is prod, but its Docker
  # containers run with ENVIRONMENT=local.
  is_local_environment = var.platform_subdomain == "local"
  smarter_environment  = local.is_local_environment ? "local" : var.environment

  oidc_provider_url = replace(data.aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")

  eks_cluster_arn = data.aws_eks_cluster.eks.arn

  # LLMHost node groups are named smarter-<environment>-<id>-<name>, see
  # smarter.apps.llmhost.models.LLMHostCompute.nodegroup_name.
  llmhost_nodegroup_prefix = "smarter-${local.smarter_environment}-"
  llmhost_nodegroup_arn    = "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:nodegroup/${var.cluster_name}/${local.llmhost_nodegroup_prefix}*/*"

  # LLMHost node groups use the platform node group's role, which the
  # kubernetes stack's EKS module names smarter-eks-node-group-<suffix>.
  node_role_arn_pattern = "arn:aws:iam::${var.aws_account_id}:role/smarter-eks-node-group-*"
}

#------------------------------------------------------------------------------
# The platform's pods: ServiceAccount "smarter"
#------------------------------------------------------------------------------
data "aws_iam_policy_document" "smarter_pods" {

  # DNS: smarter.apps.infrastructure.providers.aws.helpers.route53
  statement {
    sid = "Route53"
    actions = [
      "route53:ChangeResourceRecordSets",
      "route53:CreateHostedZone",
      "route53:DeleteHostedZone",
      "route53:GetChange",
      "route53:GetHostedZone",
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName",
      "route53:ListResourceRecordSets",
    ]
    resources = ["*"]
  }

  # certificates of custom domains: ...providers.aws.helpers.acm
  statement {
    sid = "ACM"
    actions = [
      "acm:DeleteCertificate",
      "acm:DescribeCertificate",
      "acm:ListCertificates",
      "acm:RequestCertificate",
    ]
    resources = ["*"]
  }

  # the cluster's status, health and inventory: ...providers.aws.helpers.eks
  statement {
    sid = "EKSRead"
    actions = [
      "eks:DescribeAddon",
      "eks:DescribeCluster",
      "eks:DescribeNodegroup",
      "eks:ListAddons",
      "eks:ListInsights",
      "eks:ListNodegroups",
    ]
    resources = [
      local.eks_cluster_arn,
      "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:addon/${var.cluster_name}/*/*",
      "arn:aws:eks:${var.aws_region}:${var.aws_account_id}:nodegroup/${var.cluster_name}/*/*",
    ]
  }

  statement {
    sid       = "EKSAddonVersions"
    actions   = ["eks:DescribeAddonVersions"]
    resources = ["*"]
  }

  # LLMHost node groups: smarter.apps.llmhost.services.nodegroups. A node group
  # starts billable (often GPU) EC2 instances, which EKS launches with its own
  # service-linked role, so Smarter needs no ec2:RunInstances. It can only
  # create node groups tagged with this environment...
  statement {
    sid       = "EKSCreateNodegroup"
    actions   = ["eks:CreateNodegroup"]
    resources = [local.eks_cluster_arn]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/smarter.sh/environment"
      values   = [local.smarter_environment]
    }
  }

  # ...and change only this environment's.
  statement {
    sid = "EKSManageNodegroup"
    actions = [
      "eks:DeleteNodegroup",
      "eks:TagResource",
      "eks:UpdateNodegroupConfig",
    ]
    resources = [local.llmhost_nodegroup_arn]
  }

  # removes one idle node, as the cluster autoscaler does.
  statement {
    sid       = "AutoScalingTerminateNode"
    actions   = ["autoscaling:TerminateInstanceInAutoScalingGroup"]
    resources = ["*"]
    condition {
      test     = "StringLike"
      variable = "autoscaling:ResourceTag/eks:nodegroup-name"
      values   = ["${local.llmhost_nodegroup_prefix}*"]
    }
  }

  statement {
    sid       = "PassNodeRole"
    actions   = ["iam:PassRole"]
    resources = [local.node_role_arn_pattern]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com"]
    }
  }

  # media uploads, which django-storages saves public-read, in the
  # environment's bucket (s3.tf)
  statement {
    sid       = "S3EnvironmentBucket"
    actions   = ["s3:ListBucket"]
    resources = [module.environment_storage.s3_bucket_arn]
  }

  statement {
    sid = "S3EnvironmentObjects"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]
    resources = ["${module.environment_storage.s3_bucket_arn}/*"]
  }

  # users' data exports, downloaded with presigned urls (s3.tf)
  statement {
    sid = "S3ExportsObjects"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["${module.exports_storage.s3_bucket_arn}/*"]
  }

  # smarter.common.conf.services lists the account's regions at startup
  statement {
    sid       = "EC2Regions"
    actions   = ["ec2:DescribeRegions"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "smarter_pods" {
  name        = "${local.environment_namespace}-smarter-pods"
  path        = "/"
  description = "Smarter: what the platform's pods do in AWS, for one environment"
  policy      = data.aws_iam_policy_document.smarter_pods.json
  tags        = local.tags
}

module "smarter_irsa" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 5.34"
  create_role                   = true
  role_name                     = "${local.environment_namespace}-smarter-irsa"
  provider_url                  = local.oidc_provider_url
  role_policy_arns              = [aws_iam_policy.smarter_pods.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.environment_namespace}:smarter"]
  tags                          = local.tags
}

#------------------------------------------------------------------------------
# The MariaDB backup CronJob: ServiceAccount "smarter-backup"
#
# It uploads one file to backups/sql/ in the private backup bucket, and lists
# it to log its size. It can't read or delete a backup.
#------------------------------------------------------------------------------
data "aws_iam_policy_document" "smarter_backup" {
  statement {
    sid       = "S3PutBackup"
    actions   = ["s3:PutObject"]
    resources = ["${module.backup_storage.s3_bucket_arn}/backups/sql/*"]
  }

  statement {
    sid       = "S3ListBackups"
    actions   = ["s3:ListBucket"]
    resources = [module.backup_storage.s3_bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["backups/sql/*"]
    }
  }
}

resource "aws_iam_policy" "smarter_backup" {
  name        = "${local.environment_namespace}-smarter-backup"
  path        = "/"
  description = "Smarter: the MariaDB backup CronJob uploads its backups, for one environment"
  policy      = data.aws_iam_policy_document.smarter_backup.json
  tags        = local.tags
}

module "smarter_backup_irsa" {
  source                        = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version                       = "~> 5.34"
  create_role                   = true
  role_name                     = "${local.environment_namespace}-smarter-backup-irsa"
  provider_url                  = local.oidc_provider_url
  role_policy_arns              = [aws_iam_policy.smarter_backup.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${local.environment_namespace}:smarter-backup"]
  tags                          = local.tags
}
