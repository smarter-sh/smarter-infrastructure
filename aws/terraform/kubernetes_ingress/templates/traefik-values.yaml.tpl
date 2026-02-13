entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

forwardedHeaders:
  trustedIPs:
    - "0.0.0.0"
