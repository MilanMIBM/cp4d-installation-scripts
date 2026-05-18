#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"

eval "${OC_LOGIN}"

NAMESPACE="redhat-ods-operator"
# Service Mesh version to install: 2 or 3
SERVICE_MESH_VERSION="${SERVICE_MESH_VERSION:-2}"
TIMEOUT=60

# Skip if RHOAI operator is already installed and both DSCInitialization and DataScienceCluster are Ready
if oc get csv -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -q "Succeeded"; then
  DSCI_PHASE=$(oc get dscinitialization default-dsci -o jsonpath='{.status.phase}' 2>/dev/null || true)
  DSC_PHASE=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null || true)
  if [[ "${DSCI_PHASE}" == "Ready" && "${DSC_PHASE}" == "Ready" ]]; then
    echo "[INFO] RHOAI Operator already installed and DataScienceCluster is Ready, skipping."
    exit 0
  fi
fi

# Map CP4D VERSION to the corresponding RHOAI channel.
# Channel names are OLM channel identifiers (e.g. "2.25"), not CSV version strings.
# For unmapped versions, the default channel is resolved from the marketplace.
case "${VERSION}" in
  5.3.0|5.3.1) CHANNEL_VERSION="stable-2.25" ;;
  *)
    echo "[INFO] No fixed RHOAI channel mapping for CP4D VERSION=${VERSION}, resolving latest stable from marketplace..."
    CHANNEL_VERSION=$(oc get packagemanifest rhods-operator \
      -n openshift-marketplace \
      -o jsonpath='{.status.defaultChannel}')
    ;;
esac

echo "[INFO] CP4D VERSION=${VERSION} -> RHOAI channel=${CHANNEL_VERSION}"

# Create the namespace
oc new-project "${NAMESPACE}" 2>/dev/null || echo "[INFO] Project ${NAMESPACE} already exists, continuing."

# Create the OperatorGroup
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: rhods-operator
  namespace: ${NAMESPACE}
EOF

# Create the Subscription
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: ${NAMESPACE}
spec:
  name: rhods-operator
  channel: "${CHANNEL_VERSION}"
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  config:
    env:
      - name: "DISABLE_DSC_CONFIG"
        value: "true"
EOF


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

#---

# Wait for the operator pod to be running
echo "Waiting for rhods-operator pod to become ready (timeout: ${TIMEOUT}s)..."
ELAPSED=0
until oc get pod -n "${NAMESPACE}" -l name=rhods-operator --no-headers 2>/dev/null | grep -q .; do
  sleep 10
  ELAPSED=$(( ELAPSED + 10 ))
  CSV_STATE=$(oc get csv -n "${NAMESPACE}" --no-headers 2>/dev/null | awk '{print $1, $NF}' | head -1)
  echo "  [${ELAPSED}s] pod not yet created - CSV: ${CSV_STATE:-pending}"
  if (( ELAPSED >= TIMEOUT )); then
    echo "[ERROR] rhods-operator pod never appeared in ${NAMESPACE} after ${TIMEOUT}s." >&2
    exit 1
  fi
done
REMAINING=$(( TIMEOUT - ELAPSED ))
echo "  Pod found after ${ELAPSED}s, waiting for Ready (up to ${REMAINING}s remaining)..."
oc wait pod \
  --namespace "${NAMESPACE}" \
  --for=condition=Ready \
  --selector=name=rhods-operator \
  --timeout="${REMAINING}s"

echo "rhods-operator pod is Running."
oc get pods -n "${NAMESPACE}"

# Create DSCInitialization
echo "Creating DSCInitialization..."
oc apply -f - <<EOF
apiVersion: dscinitialization.opendatahub.io/v1
kind: DSCInitialization
metadata:
  name: default-dsci
spec:
  applicationsNamespace: redhat-ods-applications
  monitoring:
    managementState: Managed
    namespace: redhat-ods-monitoring
  serviceMesh:
    managementState: Managed
  trustedCABundle:
    managementState: Managed
    customCABundle: ""
EOF

# Wait for DSCInitialization to be Ready
echo "Waiting for DSCInitialization to reach Ready phase..."
for i in $(seq 1 30); do
  PHASE=$(oc get dscinitialization default-dsci -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "${PHASE}" == "Ready" ]] && break
  echo "  phase=${PHASE:-unknown}, retrying in 10s..."
  sleep 10
done

if [[ "${PHASE:-}" != "Ready" ]]; then
  echo "[ERROR] DSCInitialization did not reach Ready phase." >&2
  oc get dscinitialization
  exit 1
fi
echo "DSCInitialization is Ready."

# Create DataScienceCluster
echo "Creating DataScienceCluster..."
oc apply -f - <<EOF
apiVersion: datasciencecluster.opendatahub.io/v1
kind: DataScienceCluster
metadata:
  name: default-dsc
spec:
  components:
    codeflare:
      managementState: Removed
    dashboard:
      managementState: Managed
    datasciencepipelines:
      managementState: Managed
    kserve:
      managementState: Managed
      defaultDeploymentMode: RawDeployment
      serving:
        managementState: Removed
        name: knative-serving
    kueue:
      managementState: Removed
    modelmeshserving:
      managementState: Removed
    ray:
      managementState: Removed
    trainingoperator:
      managementState: Managed
    trustyai:
      managementState: Removed
    workbenches:
      managementState: Managed
EOF

# Wait for DataScienceCluster to be Ready
echo "Waiting for DataScienceCluster default-dsc to reach Ready phase..."
for i in $(seq 1 36); do
  DSC_PHASE=$(oc get datasciencecluster default-dsc -o jsonpath='{.status.phase}' 2>/dev/null || true)
  [[ "${DSC_PHASE}" == "Ready" ]] && break
  echo "  phase=${DSC_PHASE:-unknown}, retrying in 10s..."
  sleep 10
done

if [[ "${DSC_PHASE:-}" != "Ready" ]]; then
  echo "[ERROR] DataScienceCluster did not reach Ready phase." >&2
  oc get datasciencecluster default-dsc
  exit 1
fi
echo "DataScienceCluster is Ready."

# Verify expected pods in redhat-ods-applications are Running
echo "Verifying pods in redhat-ods-applications..."
KSERVE_STATE=$(oc get datasciencecluster default-dsc \
  -o jsonpath='{.spec.components.kserve.managementState}' 2>/dev/null || true)

SELECTORS=("app=kubeflow-training-operator" "app=odh-model-controller")
[[ "${KSERVE_STATE}" != "Removed" ]] && SELECTORS+=("control-plane=kserve-controller-manager")

for selector in "${SELECTORS[@]}"; do
  ELAPSED=0
  until oc get pod -n redhat-ods-applications -l "${selector}" --no-headers 2>/dev/null | grep -q .; do
    sleep 10
    ELAPSED=$(( ELAPSED + 10 ))
    echo "  [${ELAPSED}s] waiting for pod with selector ${selector}..."
    if (( ELAPSED >= TIMEOUT )); then
      echo "[ERROR] Pod with selector ${selector} never appeared after ${TIMEOUT}s." >&2
      exit 1
    fi
  done
  REMAINING=$(( TIMEOUT - ELAPSED ))
  oc wait pod \
    --namespace redhat-ods-applications \
    --for=condition=Ready \
    --selector="${selector}" \
    --timeout="${REMAINING}s"
done
oc get pods -n redhat-ods-applications

# Patch inferenceservice-config: disable managed mode and set domainTemplate to example.com
echo "Patching inferenceservice-config ConfigMap..."
oc annotate configmap inferenceservice-config \
  -n redhat-ods-applications \
  opendatahub.io/managed=false \
  --overwrite

# Patch the domainTemplate value in the ConfigMap data
CURRENT_DATA=$(oc get configmap inferenceservice-config \
  -n redhat-ods-applications \
  -o jsonpath='{.data.ingress}')

PATCHED_DATA=$(echo "${CURRENT_DATA}" | \
  sed 's|"domainTemplate": "[^"]*"|"domainTemplate": "example.com"|')

oc patch configmap inferenceservice-config \
  -n redhat-ods-applications \
  --type merge \
  --patch "{\"data\":{\"ingress\":$(echo "${PATCHED_DATA}" | jq -Rs .)}}"

echo "inferenceservice-config patched."
echo "Red Hat OpenShift AI Operator installation complete."
