#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"

eval "${OC_LOGIN}"

NAMESPACE="openshift-nfd"
TIMEOUT=300

# Skip if NFD operator is already installed and succeeded
if oc get csv -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -q "Succeeded"; then
  echo "[INFO] NFD Operator already installed in ${NAMESPACE}, skipping."
  exit 0
fi

# Create the NFD namespace if it does not already exist
oc get namespace "${NAMESPACE}" &>/dev/null || oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    name: ${NAMESPACE}
    openshift.io/cluster-monitoring: "true"
EOF

# Create the OperatorGroup
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  generateName: openshift-nfd-
  name: openshift-nfd
  namespace: ${NAMESPACE}
spec:
  targetNamespaces:
  - ${NAMESPACE}
EOF

# Create the Subscription
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nfd
  namespace: ${NAMESPACE}
spec:
  channel: "stable"
  installPlanApproval: Automatic
  name: nfd
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

echo "Waiting for NFD controller pod to become ready (timeout: ${TIMEOUT}s)..."
ELAPSED=0
INTERVAL=10
until oc get pod --namespace "${NAMESPACE}" --selector=control-plane=controller-manager --no-headers 2>/dev/null | grep -q .; do
  if (( ELAPSED >= TIMEOUT )); then
    echo "[ERROR] Timed out waiting for NFD controller pod to appear" >&2
    exit 1
  fi
  sleep ${INTERVAL}
  (( ELAPSED += INTERVAL ))
  CSV_STATE=$(oc get csv -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '{print $1, $NF}' | head -1)
  echo "  [${ELAPSED}s] pod not yet created - CSV: ${CSV_STATE:-pending}"
done
REMAINING=$(( TIMEOUT - ELAPSED ))
echo "  Pod found after ${ELAPSED}s, waiting for Ready (up to ${REMAINING}s remaining)..."
oc wait pod \
  --namespace "${NAMESPACE}" \
  --for=condition=Ready \
  --selector=control-plane=controller-manager \
  --timeout="${REMAINING}s"

echo "NFD Operator installed successfully."
oc get pods --namespace "${NAMESPACE}"
