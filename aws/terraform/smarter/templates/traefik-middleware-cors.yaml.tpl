######################################################################
# Traefik Middleware: CORS Policy
#
# This YAML template defines a Traefik Middleware for handling
# Cross-Origin Resource Sharing (CORS) headers in Kubernetes.
#
# Purpose:
#   - Allow secure cross-origin requests from specified domains.
#   - Configure allowed HTTP methods, headers, and credentials.
#
# Template Variables:
#   - ${environment_namespace}: Namespace where the middleware is deployed.
#   - ${platform_domain}: Main platform domain allowed for CORS.
#   - ${platform_api_domain}: API domain(s) allowed for CORS.
#
# Usage:
#   - Reference this middleware in your Traefik IngressRoute definitions
#     to enable CORS for your services.
#   - Update the allowed origins, methods, and headers as needed.
#
# For more information, see:
#   https://doc.traefik.io/traefik/reference/routing-configuration/http/middlewares/headers/
######################################################################
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: cors
  namespace: ${environment_namespace}
spec:
  headers:
    accessControlAllowOriginList:
      - "https://${platform_domain}"
      - "https://${platform_api_domain}"
      - "https://*.${platform_api_domain}"
      - "http://${platform_domain}"
      - "http://${platform_api_domain}"
      - "http://*.${platform_api_domain}"
    accessControlAllowMethods:
      - PUT
      - GET
      - POST
      - OPTIONS
      - DELETE
    accessControlAllowHeaders:
      - Authorization
      - DNT
      - X-CustomHeader
      - X-LANG
      - Keep-Alive
      - User-Agent
      - X-Requested-With
      - If-Modified-Since
      - Cache-Control
      - Content-Type
      - X-Api-Key
      - X-Device-Id
      - Access-Control-Allow-Origin
      - X-CSRFToken
    accessControlAllowCredentials: true
