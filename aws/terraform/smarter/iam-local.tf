#------------------------------------------------------------------------------
# usage:      Smarter app infrastructure - the identity of Smarter's local
#             Docker containers (the local environment only).
#
# Deployed pods get their AWS permissions from an IAM role (iam-irsa.tf) and
# their Kubernetes permissions from their ServiceAccount. Neither exists in
# Docker on a laptop, so the local environment has an IAM user instead, with
# exactly the pods' permissions:
#
# - AWS: the same policy as the pods, aws_iam_policy.smarter_pods, scoped to
#   the local environment (its buckets, and node groups named smarter-local-*).
#   Put its access key in the smarter repository's .env, as AWS_ACCESS_KEY_ID
#   and AWS_SECRET_ACCESS_KEY.
# - Kubernetes: Smarter authenticates to EKS with a token made from that key
#   (AWSEks.get_token). The access entry maps the user to the Kubernetes group
#   below, which has the chart's Role in the local namespace only, and the
#   read-only ClusterRole (kubernetes-rbac.tf). The Helm chart isn't deployed
#   to the local namespace, so the Role is created here.
#
# Keep the Role's rules the same as the chart's Role, in the smarter
# repository's helm/charts/smarter/templates/rbac.yaml.
#------------------------------------------------------------------------------

locals {
  local_docker_kubernetes_group = "smarter:${local.environment_namespace}"
}

resource "aws_iam_user" "local_docker" {
  count = local.is_local_environment ? 1 : 0

  name = "${local.environment_namespace}-docker"
  tags = local.tags
}

resource "aws_iam_access_key" "local_docker" {
  count = local.is_local_environment ? 1 : 0

  user = aws_iam_user.local_docker[0].name
}

resource "aws_iam_user_policy_attachment" "local_docker" {
  count = local.is_local_environment ? 1 : 0

  user       = aws_iam_user.local_docker[0].name
  policy_arn = aws_iam_policy.smarter_pods.arn
}

resource "aws_eks_access_entry" "local_docker" {
  count = local.is_local_environment ? 1 : 0

  cluster_name      = var.cluster_name
  principal_arn     = aws_iam_user.local_docker[0].arn
  type              = "STANDARD"
  kubernetes_groups = [local.local_docker_kubernetes_group]
  tags              = local.tags
}

resource "kubernetes_role_v1" "local_docker" {
  count = local.is_local_environment ? 1 : 0

  metadata {
    name      = "smarter"
    namespace = local.environment_namespace
    labels = {
      "app.kubernetes.io/name"              = "smarter"
      "app.kubernetes.io/application-group" = "smarter"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["secrets", "services", "persistentvolumeclaims"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["certificates"]
    verbs      = ["get", "list", "watch", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "events"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding_v1" "local_docker" {
  count = local.is_local_environment ? 1 : 0

  metadata {
    name      = "smarter-docker"
    namespace = local.environment_namespace
    labels = {
      "app.kubernetes.io/name"              = "smarter"
      "app.kubernetes.io/application-group" = "smarter"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.local_docker[0].metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Group"
    name      = local.local_docker_kubernetes_group
  }
}
