######################################################################
# TraefikService: Sticky Sessions for Smarter Service
#
# This YAML template defines a TraefikService resource for enabling
# sticky sessions (session affinity) using cookies in Kubernetes.
#
# Purpose:
#   - Ensure user sessions are consistently routed to the same backend
#     service instance, improving session persistence and user experience.
#
# Template Variables:
#   - ${environment_namespace}: Namespace and cookie name prefix.
#
# Usage:
#   - Reference this TraefikService in your IngressRoute definitions
#     to enable sticky sessions for the 'smarter' service on port 8000.
#   - Adjust service name, port, or cookie settings as needed.
#
# For more information, see:
#   https://doc.traefik.io/traefik/routing/services/#sticky-sessions
######################################################################
apiVersion: traefik.io/v1alpha1
kind: TraefikService
metadata:
  name: smarter
  namespace: ${environment_namespace}
spec:
  weighted:
    services:
      - name: smarter
        port: 8000
    sticky:
      cookie:
        name: ${environment_namespace}_sticky_session
        httpOnly: true
        secure: true
        sameSite: none
