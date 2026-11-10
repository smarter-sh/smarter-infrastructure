#------------------------------------------------------------------------------
# usage:      Smarter app infrastructure - this environment's deploy user.
#
# The GitHub Actions workflows of smarter-sh/smarter build and deploy each
# environment with this IAM user's access key, stored as the GitHub
# environment's secrets AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY. Each
# environment has its own user, so a key that leaks from one environment's
# workflow can't change another. The platform's pods don't use it: they have
# their own role (iam-irsa.tf).
#
# What the workflows do with it:
# - push and check the environment's image in its ECR repository (ecr.tf), and
#   log in to ECR Public to pull build images;
# - aws eks update-kubeconfig, then helm and kubectl in this environment's
#   namespace only, with the EKS access entry below;
# - send the "deployed" email with SES.
#
# The secret access key is in the Terraform state, like the SMTP user's
# (iam.tf). Copy it into the GitHub environment's secrets, then rotate it by
# tainting aws_iam_access_key.deploy[0].
#------------------------------------------------------------------------------

resource "aws_iam_user" "deploy" {
  count = local.is_local_environment ? 0 : 1

  name = "${local.environment_namespace}-deploy"
  tags = local.tags
}

resource "aws_iam_access_key" "deploy" {
  count = local.is_local_environment ? 0 : 1

  user = aws_iam_user.deploy[0].name
}

data "aws_iam_policy_document" "deploy" {
  count = local.is_local_environment ? 0 : 1

  statement {
    sid = "ECRAuthorization"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr-public:GetAuthorizationToken",
      "sts:GetServiceBearerToken",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ECRPushEnvironmentImage"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.smarter.arn]
  }

  statement {
    sid       = "EKSKubeconfig"
    actions   = ["eks:DescribeCluster"]
    resources = [data.aws_eks_cluster.eks.arn]
  }

  statement {
    sid       = "SESDeployedEmail"
    actions   = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "deploy" {
  count = local.is_local_environment ? 0 : 1

  name        = "${local.environment_namespace}-deploy"
  path        = "/"
  description = "Smarter: what the build and deploy workflows do in AWS, for one environment"
  policy      = data.aws_iam_policy_document.deploy[0].json
  tags        = local.tags
}

resource "aws_iam_user_policy_attachment" "deploy" {
  count = local.is_local_environment ? 0 : 1

  user       = aws_iam_user.deploy[0].name
  policy_arn = aws_iam_policy.deploy[0].arn
}

# Kubernetes: admin of this environment's namespace, and nothing else. The
# smarter deploy workflow sets the Helm chart's serviceAccount.createClusterRole
# to false, so the chart creates only namespaced resources, and helm upgrade
# needs no more. The cluster-wide ClusterRole is created by kubernetes-rbac.tf.
#
# The access policy alone is not enough to deploy the chart: when Helm creates
# or updates a Role or RoleBinding, Kubernetes requires the deployer to hold
# every permission in it through RBAC, or to have the RBAC verbs escalate and
# bind. Permissions from an EKS access policy don't count. So the access entry
# also puts the user in a Kubernetes group, which the Role below gives escalate
# and bind on Roles and RoleBindings, in this namespace only.
locals {
  deploy_kubernetes_group = "smarter-deploy:${local.environment_namespace}"
}

resource "aws_eks_access_entry" "deploy" {
  count = local.is_local_environment ? 0 : 1

  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_user.deploy[0].arn
  type              = "STANDARD"
  kubernetes_groups = [local.deploy_kubernetes_group]
  tags              = local.tags
}

resource "kubernetes_role_v1" "deploy_rbac" {
  count = local.is_local_environment ? 0 : 1

  metadata {
    name      = "smarter-deploy-rbac"
    namespace = local.environment_namespace
    labels = {
      "app.kubernetes.io/name"              = "smarter"
      "app.kubernetes.io/application-group" = "smarter"
    }
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["escalate", "bind"]
  }
}

resource "kubernetes_role_binding_v1" "deploy_rbac" {
  count = local.is_local_environment ? 0 : 1

  metadata {
    name      = "smarter-deploy-rbac"
    namespace = local.environment_namespace
    labels = {
      "app.kubernetes.io/name"              = "smarter"
      "app.kubernetes.io/application-group" = "smarter"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.deploy_rbac[0].metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = local.deploy_kubernetes_group
  }
}

resource "aws_eks_access_policy_association" "deploy" {
  count = local.is_local_environment ? 0 : 1

  cluster_name  = var.cluster_name
  principal_arn = aws_iam_user.deploy[0].arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"

  access_scope {
    type       = "namespace"
    namespaces = [local.environment_namespace]
  }

  depends_on = [aws_eks_access_entry.deploy]
}
