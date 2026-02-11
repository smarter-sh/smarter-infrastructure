#------------------------------------------------------------------------------
# written by:   Lawrence McDaniel
#               https://lawrencemcdaniel.com
#
# date:         oct-2022
#
# usage:        create a default cluster-wide nginx-ingress-controller
#               to be used by any ingress anywhere in the cluster
#               that does not explicitly specify a different class.
#
# see:          https://github.com/kubernetes/ingress-nginx/issues/5593
#               https://kubernetes.io/docs/concepts/services-networking/ingress/#ingress-class
#
# helm reference:
#   brew install helm
#
#   helm repo add ingress-nginx https://github.com/kubernetes/ingress-nginx
#   helm repo update
#   helm show all ingress-nginx/ingress-nginx
#   helm show values ingress-nginx/ingress-nginx

#------------------------------------------------------------------------------
locals {
  templatefile_nginx_values = templatefile("${path.module}/yml/nginx-values.yaml", {})

  tags = merge(
    var.tags,
    {
      "smarter"    = "true"
    }
  )
}

resource "helm_release" "ingress_nginx_controller" {
  name             = "common"
  namespace        = var.namespace
  create_namespace = false

  chart      = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  version    = "4.14.1"

  values = [
    local.templatefile_nginx_values,
    yamlencode({
      controller = {
        config = {
          enable-cors            = "true"
          cors-allow-origin      = "*"
          cors-allow-methods     = "GET, PUT, POST, DELETE, PATCH, OPTIONS"
          cors-allow-headers     = "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range"
          cors-expose-headers    = "Content-Length,Content-Range"
          cors-allow-credentials = "true"
          cors-max-age           = "86400"

          use-proxy-protocol     = "true"
          real-ip-header         = "proxy_protocol"
          set-real-ip-from       = "0.0.0.0/0"  # Trust all sources since CLB is the proxy
        }
        # Enable Proxy Protocol on the service level
        service = {
          enableHttp  = true
          enableHttps = true
          # This tells the pods to expect Proxy Protocol
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol" = "*"
          }
        }
        ingressClassResource = {
          name = "default"
        }
        # mcdaniel: setting this nginx ingress controller to be
        #           the "default" controller means that all ingress
        #           objects will, by default, create their nginx
        #           virtual server on THIS nginx instance regardless
        #           of what other nginx servers might exist on this
        #           cluster.
        # see: https://kubernetes.github.io/ingress-nginx/user-guide/multiple-ingress/
        ingressClass = {
          default = true
        }
        # Accept old-style kubernetes.io/ingress.class annotations
        watchIngressWithoutClass = true
      }
      service = {
        type = "ClusterIP"
        annotations = {
          "service.beta.kubernetes.io/aws-load-balancer-proxy-protocol"        = "*"
          "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout" = "60"
        }
      }
    })
  ]

}

