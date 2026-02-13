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
