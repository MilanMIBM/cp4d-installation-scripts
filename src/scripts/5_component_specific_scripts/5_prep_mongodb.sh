#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---
### the service route TLS Settings must be set to 
    # 'Termination type: edge'
    # 'Insecure traffic: Redirect'
# to makemongodb ops urls accessible


for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS PREP_MONGODB; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

echo ""
echo "=== Patching CPDMongoDBOpsManager service routes (TLS: edge / Redirect) ==="
echo ""

# Collect all CPDMongoDBOpsManager instance names in the namespace
MONGO_INSTANCES=$(oc get CPDMongoDBOpsManager -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

if [[ -z "${MONGO_INSTANCES}" ]]; then
    echo "No CPDMongoDBOpsManager instances found in namespace ${PROJECT_CPD_INST_OPERANDS}."
    exit 0
fi

for INSTANCE in ${(s: :)MONGO_INSTANCES}; do
    echo "--- Instance: ${INSTANCE} ---"

    # The ops manager route name follows the pattern: mongodb-<instance>-ops-manager-svc
    ROUTE_NAME="mongodb-${INSTANCE}-ops-manager-svc"

    if ! oc get route "${ROUTE_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" &>/dev/null; then
        echo "  [WARN] Route '${ROUTE_NAME}' not found in ${PROJECT_CPD_INST_OPERANDS}, skipping."
        echo ""
        continue
    fi

    echo "  Patching route '${ROUTE_NAME}' → termination=edge, insecureEdgeTerminationPolicy=Redirect"
    oc patch route "${ROUTE_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        --type=merge \
        -p '{"spec":{"tls":{"termination":"edge","insecureEdgeTerminationPolicy":"Redirect"}}}'

    # Retrieve URL and credentials
    OPS_URL=$(oc get CPDMongoDBOpsManager "${INSTANCE}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.status.opsmanagerURL}' 2>/dev/null)
    OPS_USER=$(oc get CPDMongoDBOpsManager "${INSTANCE}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.spec.parameters.opsusername}' 2>/dev/null)
    OPS_PASS=$(oc get CPDMongoDBOpsManager "${INSTANCE}" -n "${PROJECT_CPD_INST_OPERANDS}" \
        -o jsonpath='{.spec.parameters.opspassword}' 2>/dev/null)

    echo ""
    echo "  MongoDB Ops Manager - ${INSTANCE}"
    echo "  URL:      https://${OPS_URL}"
    echo "  Username: ${OPS_USER}"
    echo "  Password: ${OPS_PASS}"
    echo ""
done

echo "=== Done ==="
