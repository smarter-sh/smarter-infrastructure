#------------------------------------------------------------------------------
# written by: Lawrence McDaniel
#             https://lawrencemcdaniel.com/
#
# date:       July-2023
#
# usage:      Smarter app infrastructure - create Kubernetes namespace
#             for this environment
#------------------------------------------------------------------------------

# typically is of the form "smarter-platform-prod" or "smarter-platform-alpha"
resource "kubernetes_namespace_v1" "smarter" {
  metadata {
    name = local.environment_namespace
  }
}
