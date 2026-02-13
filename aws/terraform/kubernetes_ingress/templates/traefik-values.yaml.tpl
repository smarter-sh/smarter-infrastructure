
ports:
  web:
    port: 80
    expose:
      default: true
      exposedPort: 80
    protocol: TCP
    forwardedHeaders:
      trustedIPs:
        - "0.0.0.0"
  websecure:
    port: 443
    expose:
      default: true
      exposedPort: 443
    protocol: TCP
    forwardedHeaders:
      trustedIPs:
        - "0.0.0.0"
