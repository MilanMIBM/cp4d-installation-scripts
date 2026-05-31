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

eval "${OC_LOGIN}"

# ---

echo ""
echo "=== Listing CPDEdbInstances in namespace: ${PROJECT_CPD_INST_OPERANDS} ==="
oc get CPDEdbInstances -n "${PROJECT_CPD_INST_OPERANDS}" 2>/dev/null || true
echo ""

EDB_INSTANCES=(${(f)"$(oc get CPDEdbInstances -n "${PROJECT_CPD_INST_OPERANDS}" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)"})

if [[ ${#EDB_INSTANCES[@]} -eq 0 ]]; then
    echo "[WARN] No CPDEdbInstances found in ${PROJECT_CPD_INST_OPERANDS}. Nothing to do."
    exit 0
fi

# ---
# Create passthrough routes for each instance's <name>-rw service

echo "=== Creating passthrough routes ==="
echo ""

for INSTANCE in "${EDB_INSTANCES[@]}"; do
    [[ -z "${INSTANCE:-}" ]] && continue
    echo "--- Instance: ${INSTANCE} ---"

    SVC_NAME="${INSTANCE}-edb-db-rw"
    ROUTE_NAME="${INSTANCE}-edb-db-rw"

    if ! oc get svc "${SVC_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" &>/dev/null; then
        echo "  [WARN] Service '${SVC_NAME}' not found in ${PROJECT_CPD_INST_OPERANDS}. Skipping."
        echo ""
        continue
    fi

    if oc get route "${ROUTE_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" &>/dev/null; then
        echo "  [SKIP] Route '${ROUTE_NAME}' already exists."
    else
        oc create route passthrough "${ROUTE_NAME}" \
            --service="${SVC_NAME}" \
            -n "${PROJECT_CPD_INST_OPERANDS}" \
            --wildcard-policy=None
        echo "  [OK] Created passthrough route '${ROUTE_NAME}'."
    fi

    ROUTE_HOST=$(oc get route "${ROUTE_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.spec.host}' 2>/dev/null || true)
    [[ -n "${ROUTE_HOST:-}" ]] && echo "  [INFO] Host: ${ROUTE_HOST}"
    echo ""
done

echo "=== Routes in ${PROJECT_CPD_INST_OPERANDS} ==="
oc get routes -n "${PROJECT_CPD_INST_OPERANDS}"
echo ""

# ---
# Extract credentials from each instance's -app secret and write to cpd_instance_details.sh

REPO_ROOT="$(cd "${SCRIPT_DIR}" && while [[ ! -f pyproject.toml ]]; do cd ..; done && pwd)"
VARS_FILE="${REPO_ROOT}/cp4d_config/cpd_instance_details.sh"

echo "=== Extracting EDB Postgres credentials ==="
echo ""

EDB_BLOCK="
# Written by $(basename $0) on $(date -u +"%Y-%m-%dT%H:%M:%SZ")"

for INSTANCE in "${EDB_INSTANCES[@]}"; do
    [[ -z "${INSTANCE:-}" ]] && continue
    echo "--- Instance: ${INSTANCE} ---"

    APP_SECRET="${INSTANCE}-edb-db-app"

    if ! oc get secret "${APP_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" &>/dev/null; then
        echo "  [WARN] Secret '${APP_SECRET}' not found in ${PROJECT_CPD_INST_OPERANDS}. Skipping credentials."
        echo ""
        continue
    fi

    EDB_PASSWORD=$(oc get secret "${APP_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
    EDB_USERNAME=$(oc get secret "${APP_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || true)
    EDB_DBNAME=$(oc get secret "${APP_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.dbname}' 2>/dev/null | base64 -d || true)
    EDB_LOCAL_PORT=$(oc get secret "${APP_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.port}' 2>/dev/null | base64 -d || true)
    EDB_LOCAL_URI=$(oc get secret "${APP_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.data.uri}' 2>/dev/null | base64 -d || true)

    ROUTE_HOST=$(oc get route "${INSTANCE}-edb-db-rw" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.spec.host}' 2>/dev/null || true)

    # Build the route URI by replacing the host in the local URI with the route host, and the port with 443
    # Local URI format: postgresql://user:pass@host:port/dbname
    if [[ -n "${EDB_LOCAL_URI:-}" && -n "${ROUTE_HOST:-}" ]]; then
        # Extract URI prefix (scheme://user:pass@) and suffix (/dbname...)
        URI_PREFIX="${EDB_LOCAL_URI%%@*}@"
        URI_SUFFIX="/${EDB_LOCAL_URI##*/}"
        EDB_ROUTE_URI="${URI_PREFIX}${ROUTE_HOST}:443${URI_SUFFIX}"
    else
        EDB_ROUTE_URI=""
    fi

    # Sanitize instance name to uppercase with underscores for variable names
    VAR_PREFIX="EDB_POSTGRES_${INSTANCE:u}"
    VAR_PREFIX="${VAR_PREFIX//-/_}"

    echo "  Username : ${EDB_USERNAME}"
    echo "  DB Name  : ${EDB_DBNAME}"
    echo "  Local Port: ${EDB_LOCAL_PORT}"
    echo "  Route Host: ${ROUTE_HOST:-[not found]}"
    echo ""

    EDB_BLOCK+="
#--- EDB Postgres - ${INSTANCE}
export ${VAR_PREFIX}_PASSWORD=\"${EDB_PASSWORD}\"
export ${VAR_PREFIX}_USERNAME=\"${EDB_USERNAME}\"
export ${VAR_PREFIX}_DBNAME=\"${EDB_DBNAME}\"
export ${VAR_PREFIX}_LOCAL_PORT=\"${EDB_LOCAL_PORT}\"
export ${VAR_PREFIX}_LOCAL_URI=\"${EDB_LOCAL_URI}\"
export ${VAR_PREFIX}_ROUTE_PORT=\"443\"
export ${VAR_PREFIX}_ROUTE_URI=\"${EDB_ROUTE_URI}\""
done

if [[ -f "${VARS_FILE}" ]]; then
    echo "${EDB_BLOCK}" >> "${VARS_FILE}"
    echo "[INFO] EDB Postgres credentials appended to ${VARS_FILE##*/}"
else
    mkdir -p "$(dirname "${VARS_FILE}")"
    echo "${EDB_BLOCK}" > "${VARS_FILE}"
    echo "[INFO] EDB Postgres credentials written to ${VARS_FILE##*/}"
fi

echo ""
echo "=== Done ==="
