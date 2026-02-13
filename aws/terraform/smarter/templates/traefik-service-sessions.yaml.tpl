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
