#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# (legacy hardcoded sourcing - replaced by universal crawl below)
# source "${SCRIPT_DIR}/../source_env_setup.sh"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

# ---
eval "${OC_LOGIN}"

oc create namespace openshift-cert-manager-operator --dry-run=client -o yaml | oc apply -f -

oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cert-manager-operator-group
  namespace: openshift-cert-manager-operator
spec:
  targetNamespaces:
  - openshift-cert-manager-operator
EOF

oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: openshift-cert-manager-operator
spec:
  channel: stable-v1
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

CERT_MANAGER_NS="openshift-cert-manager-operator"
CERT_MANAGER_LABEL="operators.coreos.com/openshift-cert-manager-operator.openshift-cert-manager-operator"
CERT_MANAGER_TIMEOUT="${CERT_MANAGER_TIMEOUT:-600}"   # total seconds to wait for the CSV to reach Succeeded

echo "[INFO] Waiting for cert-manager-operator CSV to appear and succeed (timeout ${CERT_MANAGER_TIMEOUT}s)..."

cert_manager_phase() {
    oc get csv -n "${CERT_MANAGER_NS}" -l "${CERT_MANAGER_LABEL}" \
        -o jsonpath='{.items[0].status.phase}' 2>/dev/null || true
}

deadline=$((SECONDS + CERT_MANAGER_TIMEOUT))
phase=""
while (( SECONDS < deadline )); do
    phase="$(cert_manager_phase)"
    case "${phase}" in
        Succeeded)
            break
            ;;
        Failed)
            echo "[WARN] cert-manager-operator CSV entered phase 'Failed'. Continuing anyway - verify manually with:" >&2
            echo "       oc get csv -n ${CERT_MANAGER_NS}" >&2
            break
            ;;
        "")
            echo "[INFO] CSV not created yet by OLM, waiting..."
            ;;
        *)
            echo "[INFO] CSV phase: ${phase}"
            ;;
    esac
    sleep 10
done

if [[ "${phase}" == "Succeeded" ]]; then
    echo "[INFO] cert-manager Operator for Red Hat OpenShift installed successfully."
else
    echo "[WARN] cert-manager-operator CSV did not reach 'Succeeded' within ${CERT_MANAGER_TIMEOUT}s (last phase: '${phase:-none}')." >&2
    echo "[WARN] Not failing the install - check the operator status manually with:" >&2
    echo "       oc get csv,subscription,installplan -n ${CERT_MANAGER_NS}" >&2
fi
