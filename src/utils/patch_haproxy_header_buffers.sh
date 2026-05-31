#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/source_env_setup.sh"

# ---

# Target buffer sizes in bytes. Override from environment if needed:
#   HAPROXY_HEADER_BUFFER_BYTES=131072 ./patch_haproxy_header_buffers.sh
# Default is 65536 (64 KB); OpenShift's built-in default is 32768 (32 KB).
# headerBufferBytes must be greater than headerBufferMaxRewriteBytes.
HEADER_BUFFER_BYTES="${HAPROXY_HEADER_BUFFER_BYTES:-65536}"
HEADER_BUFFER_MAX_REWRITE_BYTES="${HAPROXY_HEADER_BUFFER_MAX_REWRITE_BYTES:-8192}"

for var in OC_LOGIN; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "[ERROR] ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

INGRESS_NS="openshift-ingress-operator"
INGRESS_NS_PODS="openshift-ingress"
INGRESS_CONTROLLER="default"

echo "[INFO] Target HAProxy header buffer sizes:"
echo "         headerBufferBytes:            ${HEADER_BUFFER_BYTES} bytes ($(( HEADER_BUFFER_BYTES / 1024 )) KB)"
echo "         headerBufferMaxRewriteBytes:  ${HEADER_BUFFER_MAX_REWRITE_BYTES} bytes"

# ── 1. Check current tuning options ──────────────────────────────────────────

CURRENT=$(oc get ingresscontroller "${INGRESS_CONTROLLER}" -n "${INGRESS_NS}" \
    -o jsonpath='{.spec.tuningOptions}' 2>/dev/null || true)

echo "[INFO] Current tuningOptions: ${CURRENT:-<none>}"

CURRENT_BYTES=$(oc get ingresscontroller "${INGRESS_CONTROLLER}" -n "${INGRESS_NS}" \
    -o jsonpath='{.spec.tuningOptions.headerBufferBytes}' 2>/dev/null || true)

if [[ "${CURRENT_BYTES}" == "${HEADER_BUFFER_BYTES}" ]]; then
    echo "[INFO] headerBufferBytes already set to ${HEADER_BUFFER_BYTES}. No change needed."
    exit 0
fi

# ── 2. Patch the ingress controller ──────────────────────────────────────────

oc patch ingresscontroller "${INGRESS_CONTROLLER}" -n "${INGRESS_NS}" --type=merge -p "{
  \"spec\": {
    \"tuningOptions\": {
      \"headerBufferBytes\": ${HEADER_BUFFER_BYTES},
      \"headerBufferMaxRewriteBytes\": ${HEADER_BUFFER_MAX_REWRITE_BYTES}
    }
  }
}"

echo "[OK]  IngressController patched."

# ── 3. Wait for HAProxy router pods to roll out ───────────────────────────────
# The patch triggers a rolling restart of all router pods in openshift-ingress.

echo ""
echo "[INFO] Waiting for HAProxy router rollout to complete..."
oc rollout status deployment/router-default -n "${INGRESS_NS_PODS}" --timeout=900s
echo "[OK]  HAProxy router pods restarted successfully."

# ── 4. Confirm applied value ──────────────────────────────────────────────────

echo ""
echo "[INFO] Applied tuningOptions:"
oc get ingresscontroller "${INGRESS_CONTROLLER}" -n "${INGRESS_NS}" \
    -o jsonpath='{.spec.tuningOptions}' | python3 -m json.tool 2>/dev/null || \
oc get ingresscontroller "${INGRESS_CONTROLLER}" -n "${INGRESS_NS}" \
    -o jsonpath='{.spec.tuningOptions}'
echo ""
