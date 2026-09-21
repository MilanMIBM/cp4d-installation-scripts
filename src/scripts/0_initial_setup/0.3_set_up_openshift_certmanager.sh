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
source "${_CP4D_REPO_ROOT}/src/scripts/operator_install_helpers.sh"

# ---
eval "${OC_LOGIN}"

CERT_MANAGER_NS="openshift-cert-manager-operator"
CERT_MANAGER_CHANNEL="stable-v1"
CSV_TIMEOUT=600

# --- Existing-install handling -------------------------------------------------
# Skip when the operator is already healthy AND its operand controllers are up,
# so a re-run neither duplicates OLM objects nor re-waits ten minutes on an
# install that is already finished. The operand check matters: the CSV can be
# Succeeded while the cert-manager controllers themselves are absent, and the
# rest of this script (and everything downstream of it) depends on those pods.
CM_PHASE="$(cp4d_csv_phase "${CERT_MANAGER_NS}" "cert-manager-operator")"

if [[ "${CM_PHASE}" == "Succeeded" ]]; then
  CM_OPERAND_READY=true
  for _dep in cert-manager cert-manager-cainjector cert-manager-webhook; do
    _avail=$(oc get deployment "${_dep}" -n cert-manager \
      -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || true)
    [[ "${_avail}" == "True" ]] || CM_OPERAND_READY=false
  done
  unset _dep _avail

  if [[ "${CM_OPERAND_READY}" == "true" ]]; then
    CHANNEL_STATE="$(cp4d_reconcile_subscription_channel \
      "${CERT_MANAGER_NS}" "openshift-cert-manager-operator" "${CERT_MANAGER_CHANNEL}")" || {
      echo "[ERROR] cert-manager is on an incompatible channel for target ${CERT_MANAGER_CHANNEL}; migrate it manually." >&2
      exit 1
    }
    case "${CHANNEL_STATE}" in
      match)
        echo "[INFO] cert-manager already installed on channel ${CERT_MANAGER_CHANNEL} and controllers are Available, skipping."
        exit 0
        ;;
      patched)
        echo "[INFO] cert-manager Subscription channel patched to ${CERT_MANAGER_CHANNEL}; waiting for OLM to roll the upgrade."
        cp4d_wait_for_csv "${CERT_MANAGER_NS}" "cert-manager-operator" "${CSV_TIMEOUT}"
        echo "[INFO] cert-manager upgraded to channel ${CERT_MANAGER_CHANNEL} successfully."
        exit 0
        ;;
      absent)
        echo "[INFO] cert-manager CSV is Succeeded but has no Subscription; reconciling."
        ;;
    esac
  else
    echo "[INFO] cert-manager CSV is Succeeded but its controllers are not Available; reconciling."
  fi
fi

cp4d_ensure_namespace "${CERT_MANAGER_NS}"

# Only create an OperatorGroup when the namespace has none: a second group in the
# namespace makes OLM fail every CSV in it (TooManyOperatorGroups), and an
# existing group often carries a different name, so a named `oc apply` would add
# rather than update.
cp4d_ensure_operatorgroup "${CERT_MANAGER_NS}" "cert-manager-operator-group" "${CERT_MANAGER_NS}"

oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: openshift-cert-manager-operator
  namespace: ${CERT_MANAGER_NS}
spec:
  channel: ${CERT_MANAGER_CHANNEL}
  name: openshift-cert-manager-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF

# The CSV is labelled by OLM with operators.coreos.com/<operator>.<namespace>.
# Poll on that label rather than on the Subscription's .status.installedCSV:
# the label lives on the CSV and survives even if the Subscription is later
# removed, whereas the Subscription may be absent on a re-run or after cleanup.
CSV_LABEL="operators.coreos.com/openshift-cert-manager-operator.${CERT_MANAGER_NS}"

echo "[INFO] Waiting for OLM to create the cert-manager-operator CSV..."
_csv_name=""
_deadline=$(( $(date +%s) + CSV_TIMEOUT ))
while [[ -z "${_csv_name}" ]]; do
    _csv_name="$(oc get csv -n "${CERT_MANAGER_NS}" \
        -l "${CSV_LABEL}" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [[ -n "${_csv_name}" ]]; then
        break
    fi
    if (( $(date +%s) >= _deadline )); then
        echo "[ERROR] No CSV matching ${CSV_LABEL} appeared within ${CSV_TIMEOUT}s." >&2
        oc get subscription,installplan,csv -n "${CERT_MANAGER_NS}" >&2 || true
        exit 1
    fi
    sleep 5
done
echo "[INFO] Found CSV: ${_csv_name}"

echo "[INFO] Waiting for CSV ${_csv_name} to reach phase Succeeded..."
_remaining=$(( _deadline - $(date +%s) ))
(( _remaining < 30 )) && _remaining=30
oc wait --for=jsonpath='{.status.phase}'=Succeeded "csv/${_csv_name}" \
    -n "${CERT_MANAGER_NS}" \
    --timeout="${_remaining}s"

# The operator reconciles the CertManager/cluster CR and creates the actual
# controllers (cert-manager, -cainjector, -webhook) in the "cert-manager"
# namespace a few seconds after the CSV succeeds. Wait for them to appear
# before waiting on their condition, for the same reason as the CSV above.
CERT_MANAGER_OPERAND_NS="cert-manager"
OPERAND_DEPLOYMENTS=(cert-manager cert-manager-cainjector cert-manager-webhook)

echo "[INFO] Waiting for cert-manager controller deployments to be created..."
for _dep in "${OPERAND_DEPLOYMENTS[@]}"; do
    while ! oc get deployment "${_dep}" -n "${CERT_MANAGER_OPERAND_NS}" >/dev/null 2>&1; do
        if (( $(date +%s) >= _deadline )); then
            echo "[ERROR] Deployment ${_dep} was not created within the timeout." >&2
            oc get certmanager cluster -o yaml >&2 || true
            oc get deployment -n "${CERT_MANAGER_OPERAND_NS}" >&2 || true
            exit 1
        fi
        sleep 5
    done
done

echo "[INFO] Waiting for cert-manager controllers to become available..."
oc wait --for=condition=Available deployment \
    -l app.kubernetes.io/instance=cert-manager \
    -n "${CERT_MANAGER_OPERAND_NS}" \
    --timeout=300s

echo "[INFO] cert-manager Operator for Red Hat OpenShift installed successfully."
