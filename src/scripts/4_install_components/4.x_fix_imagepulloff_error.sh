#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi
# Re-exec under zsh if running under a different shell (e.g. bash)
if [ -z "${ZSH_VERSION:-}" ]; then exec /bin/zsh "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---

for var in OC_LOGIN PROJECT_CPD_INST_OPERATORS PROJECT_CPD_INST_OPERANDS; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

_fix_namespace() {
    local NS="$1"

    echo ""
    echo "=== Linking ibm-image-pull-secret to all service accounts in ${NS} ==="

    local SA_NAMES
    SA_NAMES=(${(f)"$(oc get sa -n "${NS}" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)"})

    for SA_NAME in "${SA_NAMES[@]}"; do
        local ALREADY_LINKED
        ALREADY_LINKED=$(oc get sa "${SA_NAME}" -n "${NS}" -o jsonpath='{.imagePullSecrets[*].name}' 2>/dev/null || true)
        if [[ "${ALREADY_LINKED}" == *"ibm-image-pull-secret"* ]]; then
            echo "[SKIP] ${SA_NAME} already has ibm-image-pull-secret linked."
        else
            oc secrets link "${SA_NAME}" ibm-image-pull-secret --for=pull -n "${NS}"
            echo "[OK] Linked ibm-image-pull-secret to SA: ${SA_NAME}"
        fi
    done

    local STUCK_PODS
    STUCK_PODS=(${(f)"$(oc get pods -n "${NS}" --no-headers 2>/dev/null | grep -E 'ImagePullBackOff|ErrImagePull' | awk '{print $1}' || true)"})

    if [[ ${#STUCK_PODS[@]} -gt 0 && -n "${STUCK_PODS[1]:-}" ]]; then
        echo "[INFO] Restarting ${#STUCK_PODS[@]} stuck pod(s)..."
        for POD in "${STUCK_PODS[@]}"; do
            oc delete pod "${POD}" -n "${NS}" --grace-period=0 2>/dev/null || true
            echo "[OK] Deleted stuck pod: ${POD}"
        done
    else
        echo "[INFO] No stuck pods found."
    fi
}

_fix_namespace "${PROJECT_CPD_INST_OPERATORS}"
_fix_namespace "${PROJECT_CPD_INST_OPERANDS}"
