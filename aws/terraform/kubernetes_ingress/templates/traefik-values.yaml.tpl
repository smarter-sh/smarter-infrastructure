
ports:
  web:
    port: 80
    expose:
      default: true
      exposedPort: 80
    protocol: TCP
    forwardedHeaders:
      trustedIPs:
        - "192.168.0.0/20"
    proxyProtocol:
      trustedIPs:
        - "192.168.0.0/20"

  websecure:
    port: 443
    expose:
      default: true
      exposedPort: 443
    protocol: TCP
    forwardedHeaders:
      trustedIPs:
        - "192.168.0.0/20"
    proxyProtocol:
      trustedIPs:
        - "192.168.0.0/20"

service:
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
    service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
    service.beta.kubernetes.io/aws-load-balancer-proxy-protocol: "*"

  spec:
    externalTrafficPolicy: Local
    sessionAffinity: None

additionalArguments:
  - "--entrypoints.web.address=:80"
  - "--entrypoints.websecure.address=:443"
  - "--providers.kubernetesingress=true"
  - "--providers.kubernetescrd=true"
  - "--log.level=INFO"
  - "--accesslog=true"
