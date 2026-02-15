######################################################################
# Kubernetes Ingress Resource for Smarter Platform
#
# This YAML template defines an Ingress resource for exposing a service
# via HTTP/HTTPS using Traefik and cert-manager in Kubernetes.
#
# Purpose:
#   - Route external traffic to the Smarter app and Api.
#   - Apply CORS and HTTPS redirect middlewares via Traefik.
#   - Enable TLS termination using cert-manager.
#
# Template Variables:
#   - ${domain}: The domain name for the ingress host and TLS secret.
#   - ${environment_namespace}: Namespace for the ingress and middlewares.
#   - ${cluster_issuer}: cert-manager ClusterIssuer for TLS certificates.
#   - ${service_name}: Name of the backend Kubernetes service.
#
# Usage:
#   - Deploy this Ingress to expose your service securely with CORS and
#     HTTPS enforced, and automatic TLS certificate management.
#   - Adjust annotations, rules, and service details as needed.
#
# For more information, see:
#   https://kubernetes.io/docs/concepts/services-networking/ingress/
#   https://cert-manager.io/docs/
######################################################################
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${domain}
  namespace: ${environment_namespace}
  annotations:
    cert-manager.io/cluster-issuer: ${cluster_issuer}
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.middlewares: ${environment_namespace}-cors@kubernetescrd,${environment_namespace}-https-redirect@kubernetescrd
spec:
  rules:
    - host: ${domain}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${service_name}
                port:
                  number: 8000
  tls:
    - hosts:
        - ${domain}
      secretName: ${domain}-tls
