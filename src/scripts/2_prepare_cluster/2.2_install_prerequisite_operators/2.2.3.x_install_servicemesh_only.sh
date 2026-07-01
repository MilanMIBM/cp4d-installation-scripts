#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# (legacy hardcoded sourcing - replaced by universal crawl below)
# source "${SCRIPT_DIR}/../../source_env_setup.sh"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

eval "${OC_LOGIN}"

# Service Mesh version to install: 2 or 3
SERVICE_MESH_VERSION="${SERVICE_MESH_VERSION:-3}"
TIMEOUT=60

# --- Service Mesh Install ---
# Installs cluster-wide into openshift-operators; the global OperatorGroup already exists.
if [[ "${SERVICE_MESH_VERSION}" == "3" ]]; then
  SM_OPERATOR="servicemeshoperator3"
  SM_CHANNEL="stable"
  echo "[INFO] Installing Red Hat OpenShift Service Mesh 3..."
elif [[ "${SERVICE_MESH_VERSION}" == "2" ]]; then
  SM_OPERATOR="servicemeshoperator"
  SM_CHANNEL="stable"
  echo "[INFO] Installing Red Hat OpenShift Service Mesh 2..."
else
  echo "[ERROR] Unsupported SERVICE_MESH_VERSION=${SERVICE_MESH_VERSION}. Must be 2 or 3." >&2
  exit 1
fi

if oc get csv -n openshift-operators --no-headers 2>/dev/null | grep -q "^${SM_OPERATOR}.*Succeeded"; then
  echo "[INFO] Service Mesh ${SERVICE_MESH_VERSION} operator already installed, skipping."
else
  oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${SM_OPERATOR}
  namespace: openshift-operators
spec:
  channel: ${SM_CHANNEL}
  name: ${SM_OPERATOR}
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

  echo "Waiting for Service Mesh ${SERVICE_MESH_VERSION} CSV to reach Succeeded (timeout: ${TIMEOUT}s)..."
  ELAPSED=0
  until oc get csv -n openshift-operators --no-headers 2>/dev/null | grep -q "^${SM_OPERATOR}.*Succeeded"; do
    sleep 10
    ELAPSED=$(( ELAPSED + 10 ))
    CSV_STATE=$(oc get csv -n openshift-operators --no-headers 2>/dev/null | grep "${SM_OPERATOR}" | awk '{print $1, $NF}' || true)
    echo "  [${ELAPSED}s] CSV: ${CSV_STATE:-pending}"
    if (( ELAPSED >= TIMEOUT )); then
      echo "[ERROR] Service Mesh ${SERVICE_MESH_VERSION} CSV did not reach Succeeded after ${TIMEOUT}s." >&2
      oc get csv -n openshift-operators | grep "${SM_OPERATOR}" || true
      exit 1
    fi
  done
  echo "[INFO] Service Mesh ${SERVICE_MESH_VERSION} operator installed successfully."
fi

echo "Red Hat OpenShift Service Mesh ${SERVICE_MESH_VERSION} installation complete."
