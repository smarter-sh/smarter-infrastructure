#!/usr/bin/env bash
# Run one read-only kubectl command against a context and namespace.
#
# Usage:
#   skills/smarter-kubectl/scripts/kubectl.sh <context> <namespace> <kubectl command and args...>
#
# Examples:
#   kubectl.sh "$CTX" kube-system get pods -o wide
#   kubectl.sh "$CTX" kube-system get apiservice v1beta1.metrics.k8s.io
#   kubectl.sh "$CTX" traefik describe svc traefik
#   kubectl.sh "$CTX" tigera-operator get installation default -o yaml
#
# It passes --context and -n to kubectl rather than switching the current context, so the user's
# own kubectl keeps pointing where it was. It runs only commands that read. For anything else it
# prints the command for the user to run, and exits 2. `exec` runs only when
# SMARTER_KUBECTL_ALLOW_EXEC=1 is set, which an agent sets only after the user said yes to that
# exec. It also refuses `get` of secrets with an output format that would print their values.

set -euo pipefail

if [ $# -lt 3 ]; then
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
fi

CTX="$1"
NS="$2"
shift 2
VERB="$1"
SUB="${2:-}"

refuse() {
  echo "kubectl.sh: refused, $1. For the user to run:" >&2
  shift
  printf '  kubectl --context %q -n %q' "$CTX" "$NS" >&2
  printf ' %q' "$@" >&2
  echo >&2
  exit 2
}

# `get secret(s) -o yaml|json|jsonpath|...` prints the secret's data. Listing secrets, `-o name`,
# `-o wide` and `describe secret` (which shows only sizes) are fine.
secret_values() {
  local mentions_secret=0 out="" prev=""
  for a in "$@"; do
    case "$a" in *secret*) mentions_secret=1 ;; esac
    case "$prev" in -o | --output) out="$a" ;; esac
    case "$a" in
    --output=*) out="${a#--output=}" ;;
    -o?*) out="${a#-o}" ;;
    esac
    prev="$a"
  done
  [ "$mentions_secret" = 1 ] && [ -n "$out" ] && [ "$out" != "wide" ] && [ "$out" != "name" ]
}

case "$VERB" in
get)
  if secret_values "$@"; then
    refuse "this output format prints secret values" "$@"
  fi
  ;;
describe | logs | top | events | explain | api-resources | api-versions | version) ;;
auth) [ "$SUB" = "can-i" ] || refuse "only 'auth can-i' reads" "$@" ;;
rollout) [ "$SUB" = "history" ] || [ "$SUB" = "status" ] || refuse "only 'rollout history|status' read" "$@" ;;
exec) [ "${SMARTER_KUBECTL_ALLOW_EXEC:-}" = "1" ] || refuse "exec needs the user's OK (SMARTER_KUBECTL_ALLOW_EXEC=1)" "$@" ;;
*) refuse "'$VERB' is not a read-only command" "$@" ;;
esac

exec kubectl --context "$CTX" -n "$NS" "$@"
