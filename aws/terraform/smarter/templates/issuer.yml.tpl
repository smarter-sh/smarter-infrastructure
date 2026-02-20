######################################################################
# cert-manager ClusterIssuer for ACME (Let's Encrypt)
#
# This YAML template defines a cert-manager ClusterIssuer resource for
# obtaining TLS certificates from Let's Encrypt using the ACME protocol
# and DNS-01 challenge with AWS Route53.
#
# Purpose:
#   - Automate the issuance and renewal of TLS certificates for Kubernetes
#     resources using Let's Encrypt and cert-manager.
#
# Template Variables:
#   - ${domain}: Name for the ClusterIssuer and related secrets.
#   - ${root_domain}: Email domain for ACME registration.
#   - ${aws_region}: AWS region for Route53 DNS challenge.
#   - ${hosted_zone_id}: Route53 Hosted Zone ID for DNS-01 challenge.
#
# Usage:
#   - Deploy this ClusterIssuer to enable automatic certificate management
#     for the Smarter app and it's Api.
#   - Reference this issuer in your Ingress or Certificate resources.
#   - Adjust ACME server, email, and DNS settings as needed.
#
# For more information, see:
#   https://cert-manager.io/docs/configuration/acme/
#   https://letsencrypt.org/docs/
######################################################################
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${domain_tls}
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
      name: ${domain_tls}
    # ACME challenge solvers configuration.
    solvers:
      - dns01:
          # hosted Zone ID for for the environment domain.
          route53:
            region: ${aws_region}
            hostedZoneID: ${hosted_zone_id}
