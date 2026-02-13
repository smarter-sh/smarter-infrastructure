apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: cors
  namespace: ${environment_namespace}
spec:
  headers:
    accessControlAllowOriginList:
      - "https://${platform_domain}"
      - "https://${api_domain}"
      - "https://*.${api_domain}"
      - "http://${platform_domain}"
      - "http://${api_domain}"
      - "http://*.${api_domain}"
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
