#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi
# Re-exec under zsh if running under a different shell (e.g. bash)
if [ -z "${ZSH_VERSION:-}" ]; then exec /bin/zsh "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# (legacy hardcoded sourcing - replaced by universal crawl below)
# source "${SCRIPT_DIR}/../source_env_setup.sh"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

# ---

for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS PREP_WXO; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

# Target size for the WatsonxOrchestrate CR. Override by exporting WXO_SIZE.
# Valid values (from the WO operator sizing profile):
#   small_mincpureq - small replica counts AND every CPU request pinned to 5m
#   small           - single replica per component, stock CPU requests
#   medium          - operator default
#   large
WXO_SIZE="${WXO_SIZE:-small}"

case "${WXO_SIZE}" in
    small_mincpureq|small|medium|large) ;;
    *)
        echo "Error: WXO_SIZE='${WXO_SIZE}' is not valid."
        echo "       Expected one of: small_mincpureq, small, medium, large"
        exit 1
        ;;
esac

eval "${OC_LOGIN}"

WO_CR="wo"
NS="${PROJECT_CPD_INST_OPERANDS}"

echo "[INFO] Scaling watsonx Orchestrate to size '${WXO_SIZE}' in namespace '${NS}'..."

if ! oc get wo "${WO_CR}" -n "${NS}" >/dev/null 2>&1; then
    echo "Error: WatsonxOrchestrate CR '${WO_CR}' not found in namespace '${NS}'."
    exit 1
fi

CURRENT_SIZE="$(oc get wo "${WO_CR}" -n "${NS}" -o jsonpath='{.spec.size}' 2>/dev/null)"
echo "[INFO] Current spec.size: '${CURRENT_SIZE:-<unset, operator defaults to medium>}'"

if [[ "${CURRENT_SIZE}" == "${WXO_SIZE}" ]]; then
    echo "[INFO] Already set to '${WXO_SIZE}'. Nothing to do."
    exit 0
fi

# spec.size on the parent WatsonxOrchestrate CR is the only durable place to set
# this. The WO operator renders the child DocumentProcessing CR (wo-docproc) as a
# managed resource, so patching wo-docproc directly is reverted on every reconcile.
oc patch wo "${WO_CR}" -n "${NS}" --type=merge \
    -p "{\"spec\":{\"size\":\"${WXO_SIZE}\"}}"

echo "[INFO] Patched. Waiting for the operator to propagate size to wo-docproc..."

PROPAGATED=false
for _ in $(seq 1 60); do
    DOCPROC_SIZE="$(oc get documentprocessing wo-docproc -n "${NS}" -o jsonpath='{.spec.size}' 2>/dev/null || true)"
    if [[ "${DOCPROC_SIZE}" == "${WXO_SIZE}" ]]; then
        PROPAGATED=true
        break
    fi
    sleep 10
done

if [[ "${PROPAGATED}" == "true" ]]; then
    echo "[INFO] wo-docproc now reports spec.size='${WXO_SIZE}'."
else
    echo "[WARN] wo-docproc has not reported spec.size='${WXO_SIZE}' yet (still '${DOCPROC_SIZE:-unknown}')."
    echo "[WARN] The operator may still be reconciling. Check with:"
    echo "         oc get documentprocessing wo-docproc -n ${NS} -o jsonpath='{.spec.size}'"
fi

echo "[INFO] Reconcile is asynchronous - pods will roll as the operator applies the new profile."
echo "[INFO] Monitor progress with:"
echo "         oc get wo ${WO_CR} -n ${NS}"
echo "         oc get documentprocessing wo-docproc -n ${NS}"
echo "         oc get pods -n ${NS} | grep wo-"
echo "[INFO] Done. watsonx Orchestrate is set to size '${WXO_SIZE}'."
