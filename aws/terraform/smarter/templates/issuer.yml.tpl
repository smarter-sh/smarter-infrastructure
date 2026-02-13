apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${domain}
spec:
  acme:
    # The ACME server URL for Let's Encrypt production environment.
    # Use the staging server for testing to avoid rate limits:
    # https://acme-staging-v02.api.letsencrypt.org/directory
    server: https://acme-v02.api.letsencrypt.org/directory
    # Email address used for ACME account registration and notifications.
    email: no-reply@${root_domain}
    # Name of a Secret resource that will store the ACME account's private key.
    privateKeySecretRef:
      name: ${domain}_tls
    # ACME challenge solvers configuration.
    solvers:
      - dns01:
          # hosted Zone ID for for the environment domain.
          route53:
            region: ${aws_region}
            hostedZoneID: ${hosted_zone_id}
