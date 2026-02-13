
# 1. namespace
resource "kubernetes_namespace_v1" "smarter" {
  metadata {
    name = local.environment_namespace
  }
}
