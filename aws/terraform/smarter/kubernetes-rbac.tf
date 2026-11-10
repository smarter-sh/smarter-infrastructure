#------------------------------------------------------------------------------
# usage:      Smarter app infrastructure - the cluster-wide reads of this
#             environment's ServiceAccount "smarter".
#
# The Smarter Helm chart gives the ServiceAccount a Role in its namespace
# (helm/charts/smarter/templates/rbac.yaml), and creates nothing outside it,
# so that each environment deploys with namespace-scoped permissions (see
# iam-deploy.tf). These reads are cluster-wide, so they are created here:
# the namespace check, nodes (LLMHost capacity, cluster status),
# PersistentVolumes (the inventory) and node metrics. It is the same
# ClusterRole that the chart creates with serviceAccount.createClusterRole.
#------------------------------------------------------------------------------

resource "kubernetes_cluster_role_v1" "smarter" {
  metadata {
    name = "smarter-${local.environment_namespace}"
    labels = {
      "app.kubernetes.io/name"              = "smarter"
      "app.kubernetes.io/application-group" = "smarter"
    }
  }

  rule {
    api_groups     = [""]
    resources      = ["namespaces"]
    resource_names = [local.environment_namespace]
    verbs          = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "persistentvolumes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "smarter" {
  metadata {
    name = "smarter-${local.environment_namespace}"
    labels = {
      "app.kubernetes.io/name"              = "smarter"
      "app.kubernetes.io/application-group" = "smarter"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.smarter.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "smarter"
    namespace = local.environment_namespace
  }

  # the local environment's Docker containers (iam-local.tf)
  dynamic "subject" {
    for_each = local.is_local_environment ? [local.local_docker_kubernetes_group] : []
    content {
      api_group = "rbac.authorization.k8s.io"
      kind      = "Group"
      name      = subject.value
    }
  }
}
