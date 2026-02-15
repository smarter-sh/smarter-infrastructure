######################################################################
# Traefik Middleware: HTTP to HTTPS Redirect
#
# This YAML template defines a Traefik Middleware for redirecting
# all HTTP requests to HTTPS in Kubernetes.
#
# Purpose:
#   - Enforce secure connections by automatically redirecting HTTP
#     traffic to HTTPS for all incoming requests.
#
# Template Variables:
#   - ${environment_namespace}: Namespace where the middleware is deployed.
#
# Usage:
#   - Reference this middleware in your Traefik IngressRoute definitions
#     to ensure all HTTP traffic is redirected to HTTPS.
#   - The redirect is permanent (HTTP 301).
#
# For more information, see:
#   https://doc.traefik.io/traefik/middlewares/redirectscheme/
######################################################################
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-redirect
  namespace: ${environment_namespace}
spec:
  redirectScheme:
    scheme: https
    permanent: true
