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

for var in CPDM_OC_LOGIN PROJECT_CPD_INST_OPERANDS; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${CPDM_OC_LOGIN}"

# ---
# Expose the Informix Data Management Console (DMC) monitor service via an OCP passthrough route
# and extract credentials into cpd_instance_details.sh.
# Note: this bypasses CP4D's auth layer - DMC uses its own local credentials (not CP4D SSO).

echo "[INFO] Discovering Informix monitor service in namespace ${PROJECT_CPD_INST_OPERANDS}..."

INFORMIX_MONITOR_SVC="$(oc get svc -n "${PROJECT_CPD_INST_OPERANDS}" \
    --no-headers -o custom-columns=NAME:.metadata.name \
    | grep -- '-monitor-service$' | head -1 || true)"

if [[ -z "${INFORMIX_MONITOR_SVC}" ]]; then
    echo "[ERROR] No Informix monitor service found in ${PROJECT_CPD_INST_OPERANDS}. Is Informix installed?"
    exit 1
fi

echo "[INFO] Found monitor service: ${INFORMIX_MONITOR_SVC}"

# Derive the instance name prefix (everything before -monitor-service)
INFORMIX_INSTANCE="${INFORMIX_MONITOR_SVC%-monitor-service}"

_ROUTE_NAME="${INFORMIX_INSTANCE}-dmc-direct"
_ROUTE_EXISTS="$(oc get route "${_ROUTE_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" --ignore-not-found \
    -o jsonpath='{.metadata.name}' 2>/dev/null || true)"

if [[ -z "${_ROUTE_EXISTS}" ]]; then
    echo "[INFO] Creating passthrough route '${_ROUTE_NAME}'..."
    oc create route passthrough "${_ROUTE_NAME}" \
        --service="${INFORMIX_MONITOR_SVC}" \
        --port=8081 \
        -n "${PROJECT_CPD_INST_OPERANDS}"
else
    echo "[SKIP] Route '${_ROUTE_NAME}' already exists."
fi

INFORMIX_DMC_URL="https://$(oc get route "${_ROUTE_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" \
    -o jsonpath='{.spec.host}')"
echo "[OK] DMC URL: ${INFORMIX_DMC_URL}"

# ---
# Extract credentials from the informix-auth secret

_AUTH_SECRET="${INFORMIX_INSTANCE}-informix-auth"
echo "[INFO] Extracting credentials from secret '${_AUTH_SECRET}'..."

INFORMIX_DMC_ADMINPWD="" INFORMIX_APP_USER="" INFORMIX_APP_PASSWORD=""
for (( _attempt=1; _attempt<=5; _attempt++ )); do
    INFORMIX_DMC_ADMINPWD="$(oc get secret "${_AUTH_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.adminpwd}' 2>/dev/null | base64 --decode || true)"
    INFORMIX_APP_USER="$(oc get secret "${_AUTH_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.appusername}' 2>/dev/null | base64 --decode || true)"
    INFORMIX_APP_PASSWORD="$(oc get secret "${_AUTH_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.apppassword}' 2>/dev/null | base64 --decode || true)"
    [[ -n "${INFORMIX_DMC_ADMINPWD}" && -n "${INFORMIX_APP_USER}" && -n "${INFORMIX_APP_PASSWORD}" ]] && break
    _delay=$(( _attempt * 10 ))
    echo "[WARN] Secret '${_AUTH_SECRET}' not yet fully populated, retrying in ${_delay}s (attempt ${_attempt}/5)..." >&2
    sleep "${_delay}"
done

if [[ -z "${INFORMIX_DMC_ADMINPWD}" || -z "${INFORMIX_APP_USER}" || -z "${INFORMIX_APP_PASSWORD}" ]]; then
    echo "[WARN] Could not fully retrieve credentials from '${_AUTH_SECRET}' after 5 retries." >&2
fi

# ---
# Write credentials to cpd_instance_details.sh

REPO_ROOT="$(cd "${SCRIPT_DIR}" && while [[ ! -f pyproject.toml ]]; do cd ..; done && pwd)"
VARS_FILE="${REPO_ROOT}/cp4d_config/cpd_instance_details.sh"

INFORMIX_BLOCK="
# Written by $(basename $0) on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#--- Informix Data Management Console (DMC) - direct passthrough route (no CP4D SSO)
export INFORMIX_INSTANCE=\"${INFORMIX_INSTANCE}\"
export INFORMIX_DMC_URL=\"${INFORMIX_DMC_URL}\"
export INFORMIX_DMC_USERNAME=\"admin\"
export INFORMIX_DMC_PASSWORD=\"${INFORMIX_DMC_ADMINPWD}\"
#--- Informix app-level DB user
export INFORMIX_APP_USERNAME=\"${INFORMIX_APP_USER}\"
export INFORMIX_APP_PASSWORD=\"${INFORMIX_APP_PASSWORD}\""

if [[ -f "${VARS_FILE}" ]]; then
    echo "${INFORMIX_BLOCK}" >> "${VARS_FILE}"
    echo "[INFO] Informix DMC credentials appended to ${VARS_FILE##*/}"
else
    mkdir -p "$(dirname "${VARS_FILE}")"
    echo "${INFORMIX_BLOCK}" > "${VARS_FILE}"
    echo "[INFO] Informix DMC credentials written to ${VARS_FILE##*/}"
fi
