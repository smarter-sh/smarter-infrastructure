serviceAccount:
  annotations:
    eks.amazonaws.com/role-arn: ${role_arn}
  name: cert-manager
  automountServiceAccountToken: true
# seems that as of version 1.17 you can no longer specify a namespace
# namespace: ${namespace}
# the securityContext is required, so the pod can access files required to assume the IAM role
securityContext:
  # -------------------------------------------------------------------------------
  # mcdaniel dec-2022: see https://github.com/cert-manager/cert-manager/issues/5549
  #enabled: true
  # -------------------------------------------------------------------------------
  fsGroup: 1001
installCRDs: true
extraArgs:
  # Needed for bug: https://github.com/cert-manager/cert-manager/issues/5515#issuecomment-1479054700
  - --enable-certificate-owner-ref=true
  # https://stackoverflow.com/questions/60989753/cert-manager-is-failing-with-waiting-for-dns-01-challenge-propagation-could-not
  - --dns01-recursive-nameservers-only
  - --dns01-recursive-nameservers=8.8.8.8:53,1.1.1.1:53
