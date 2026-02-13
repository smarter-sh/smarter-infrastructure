#------------------------------------------------------------------------------
# written by:   Lawrence McDaniel
#               https://lawrencemcdaniel.com
#
# date:         oct-2022
#
# usage:        create a default cluster-wide traefik ingress controller
#               to be used by any ingress anywhere in the cluster
#               that does not explicitly specify a different class.
#
# see:          https://github.com/kubernetes/ingress-nginx/issues/5593
#               https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class
#
# helm reference:
#   brew install helm
#
#   helm repo add traefik https://traefik.github.io/charts
#   helm repo update
#   helm show all traefik/traefik
#   helm show values traefik/traefik
#------------------------------------------------------------------------------
locals {
  templatefile_nginx_values = templatefile("${path.module}/yml/nginx-values.yaml", {})
  namespace = "traefik"
  tags = merge(
    var.tags,
    {
      "smarter"    = "true"
    }
  )
}

resource "helm_release" "traefik_crds" {
  name       = "traefik-crds"
  chart      = "traefik-crds"
  repository = "https://traefik.github.io/charts"
  namespace  = local.namespace
  create_namespace = true
}

resource "helm_release" "traefik" {
  name             = "traefik"
  namespace        = local.namespace
  create_namespace = true

  chart      = "traefik"
  repository = "https://traefik.github.io/charts"

  depends_on = [ helm_release.traefik_crds ]
}

# Traefik CORS Middleware (Terraform CRD)
# resource "kubernetes_manifest" "traefik_cors_middleware" {
#   manifest = {
#     apiVersion = "traefik.io/v1alpha1"
#     kind       = "Middleware"
#     metadata = {
#       name      = "cors"
#       namespace = local.namespace
#     }
#     spec = {
#       headers = {
#         accessControlAllowMethods = [
#           "GET", "PUT", "POST", "DELETE", "PATCH", "OPTIONS"
#         ]
#         accessControlAllowOriginList = ["*"]
#         accessControlAllowHeaders = [
#           "DNT", "User-Agent", "X-Requested-With", "If-Modified-Since", "Cache-Control", "Content-Type", "Range"
#         ]
#         accessControlExposeHeaders = [
#           "Content-Length", "Content-Range"
#         ]
#         accessControlAllowCredentials = true
#         accessControlMaxAge = 86400
#       }
#     }
#   }

#   depends_on = [ helm_release.traefik_crds ]
# }



# resource "kubernetes_manifest" "ingressroute" {
#   manifest = {
#     apiVersion = "traefik.io/v1alpha1"
#     kind       = "IngressRoute"
#     metadata = {
#       name      = "example"
#       namespace = local.namespace
#     }
#     spec = {
#       entryPoints = ["web"]
#       routes = [
#         {
#           match = "Host(`example.com`)"
#           kind  = "Rule"
#           services = [
#             {
#               name = "example-service"
#               port = 80
#             }
#           ]
#           middlewares = [
#             {
#               name      = kubernetes_manifest.traefik_cors_middleware.manifest["metadata"]["name"]
#               namespace = local.namespace
#             }
#           ]
#         }
#       ]
#     }
#   }

#   depends_on = [ helm_release.traefik_crds ]
# }
