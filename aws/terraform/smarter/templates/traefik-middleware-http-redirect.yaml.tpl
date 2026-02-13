apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: https-redirect
  namespace: ${environment_namespace}
spec:
  redirectScheme:
    scheme: https
    permanent: true
