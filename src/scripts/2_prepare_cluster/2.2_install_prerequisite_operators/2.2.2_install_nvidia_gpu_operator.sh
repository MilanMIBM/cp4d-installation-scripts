#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"

eval "${OC_LOGIN}"

NAMESPACE="nvidia-gpu-operator"
TIMEOUT=120

# Skip if GPU Operator subscription already exists (installed or in progress)
if oc get subscription gpu-operator-certified -n "${NAMESPACE}" &>/dev/null; then
  CSV_STATE=$(oc get csv -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '{print $1, $NF}' | head -1)
  echo "[INFO] NVIDIA GPU Operator subscription already exists in ${NAMESPACE} (${CSV_STATE:-state unknown}), skipping."
  exit 0
fi

# Create the namespace if it does not already exist
oc get namespace "${NAMESPACE}" &>/dev/null || oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
  labels:
    openshift.io/cluster-monitoring: "true"
EOF

# Create the OperatorGroup
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: nvidia-gpu-operator-group
  namespace: ${NAMESPACE}
spec:
  targetNamespaces:
  - ${NAMESPACE}
EOF

# Resolve channel and startingCSV dynamically
echo "Resolving GPU Operator channel and CSV from marketplace..."
CHANNEL=$(oc get packagemanifest gpu-operator-certified \
  -n openshift-marketplace \
  -o jsonpath='{.status.defaultChannel}')
echo "  channel: ${CHANNEL}"

STARTING_CSV=$(oc get packagemanifests/gpu-operator-certified \
  -n openshift-marketplace \
  -ojson | jq -r --arg ch "${CHANNEL}" \
  '.status.channels[] | select(.name == $ch) | .currentCSV')
echo "  startingCSV: ${STARTING_CSV}"

# Create the Subscription
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: gpu-operator-certified
  namespace: ${NAMESPACE}
spec:
  channel: "${CHANNEL}"
  installPlanApproval: Manual
  name: gpu-operator-certified
  source: certified-operators
  sourceNamespace: openshift-marketplace
  startingCSV: "${STARTING_CSV}"
EOF

# Wait for the InstallPlan to appear then approve it
echo "Waiting for InstallPlan to be created..."
for i in $(seq 1 30); do
  INSTALL_PLAN=$(oc get installplan -n "${NAMESPACE}" -oname 2>/dev/null | head -1)
  [[ -n "${INSTALL_PLAN}" ]] && break
  sleep 10
done

if [[ -z "${INSTALL_PLAN:-}" ]]; then
  echo "[WARN] No InstallPlan found in ${NAMESPACE} after 5 minutes, continuing."
  exit 0
fi

echo "Approving InstallPlan: ${INSTALL_PLAN}"
oc patch "${INSTALL_PLAN}" -n "${NAMESPACE}" \
  --type merge \
  --patch '{"spec":{"approved":true}}'

echo "Waiting for GPU Operator pod to become ready (timeout: ${TIMEOUT}s)..."
ELAPSED=0
until oc get pod -n "${NAMESPACE}" -l app=gpu-operator --no-headers 2>/dev/null | grep -q .; do
  sleep 10
  ELAPSED=$(( ELAPSED + 10 ))
  CSV_STATE=$(oc get csv -n "${NAMESPACE}" "${STARTING_CSV}" --no-headers 2>/dev/null | awk '{print $1, $NF}')
  echo "  [${ELAPSED}s] pod not yet created - CSV: ${CSV_STATE:-pending}"
  if (( ELAPSED >= TIMEOUT )); then
    echo "[WARN] GPU Operator pod never appeared in ${NAMESPACE} after ${TIMEOUT}s, continuing."
    exit 0
  fi
done
REMAINING=$(( TIMEOUT - ELAPSED ))
echo "  Pod found after ${ELAPSED}s, waiting for Ready (up to ${REMAINING}s remaining)..."
oc wait pod \
  --namespace "${NAMESPACE}" \
  --for=condition=Ready \
  --selector=app=gpu-operator \
  --timeout="${REMAINING}s" || echo "[WARN] GPU Operator pod did not become Ready within timeout, continuing."

echo "NVIDIA GPU Operator installed successfully."
oc get pods --namespace "${NAMESPACE}"
