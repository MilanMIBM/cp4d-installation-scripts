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

for var in OC_LOGIN PREP_OPENSEARCH; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

oc get opensearchclusters -n "${PROJECT_CPD_INST_OPERANDS}"

oc get pods -n "${PROJECT_CPD_INST_OPERANDS}" | grep opensearch || true

# ---
# Expose OpenSearch service instances with passthrough routes and update Traefik TLS cert

SERVICE_IDS=(${(f)"$(oc get opensearchclusters -n "${PROJECT_CPD_INST_OPERANDS}" --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null)"})

if [[ ${#SERVICE_IDS[@]} -eq 0 ]]; then
    echo "[WARN] No OpenSearch service instances found in ${PROJECT_CPD_INST_OPERANDS}. Skipping route creation."
else
    # Identify the Traefik ingress TLS certificate name once (shared across all instances)
    TRAEFIK_CERT=$(oc -n "${PROJECT_CPD_INST_OPERATORS}" get certificate --no-headers 2>/dev/null | grep traefik-ingress-tls | awk '{print $1}' | head -n1)
    if [[ -z "${TRAEFIK_CERT:-}" ]]; then
        echo "[WARN] Could not locate a traefik-ingress-tls certificate in ${PROJECT_CPD_INST_OPERATORS}. TLS patching will be skipped."
    fi

    for SERVICE_ID in "${SERVICE_IDS[@]}"; do
        echo ""
        echo "=== Exposing OpenSearch service: ${SERVICE_ID} ==="

        # Create passthrough route for OpenSearch backend (port 9200)
        if oc get route "${SERVICE_ID}-backend" -n "${PROJECT_CPD_INST_OPERATORS}" &>/dev/null; then
            echo "[SKIP] Route ${SERVICE_ID}-backend already exists."
        else
            oc create route passthrough "${SERVICE_ID}-backend" \
                --service=ibm-wxd-opensearch-traefik \
                --port=9200 \
                -n "${PROJECT_CPD_INST_OPERATORS}" \
                --wildcard-policy=None
            echo "[OK] Created route ${SERVICE_ID}-backend (port 9200)."
        fi

        # Create passthrough route for OpenSearch Dashboards (port 5601)
        if oc get route "${SERVICE_ID}-dashboards" -n "${PROJECT_CPD_INST_OPERATORS}" &>/dev/null; then
            echo "[SKIP] Route ${SERVICE_ID}-dashboards already exists."
        else
            oc create route passthrough "${SERVICE_ID}-dashboards" \
                --service=ibm-wxd-opensearch-traefik \
                --port=5601 \
                -n "${PROJECT_CPD_INST_OPERATORS}" \
                --wildcard-policy=None
            echo "[OK] Created route ${SERVICE_ID}-dashboards (port 5601)."
        fi

        # Obtain the backend route hostname and patch the Traefik TLS cert to include it
        if [[ -n "${TRAEFIK_CERT:-}" ]]; then
            BACKEND_HOST=$(oc get route "${SERVICE_ID}-backend" -n "${PROJECT_CPD_INST_OPERATORS}" --no-headers -o custom-columns=HOST:.spec.host 2>/dev/null || true)
            DASHBOARDS_HOST=$(oc get route "${SERVICE_ID}-dashboards" -n "${PROJECT_CPD_INST_OPERATORS}" --no-headers -o custom-columns=HOST:.spec.host 2>/dev/null || true)

            for HOSTNAME in "${BACKEND_HOST}" "${DASHBOARDS_HOST}"; do
                [[ -z "${HOSTNAME:-}" ]] && continue
                echo "[INFO] Patching Traefik cert ${TRAEFIK_CERT} to add dnsName: ${HOSTNAME}"
                oc -n "${PROJECT_CPD_INST_OPERATORS}" patch certificate "${TRAEFIK_CERT}" \
                    --type='json' \
                    -p="[{\"op\":\"add\",\"path\":\"/spec/dnsNames/-\",\"value\":\"${HOSTNAME}\"}]"
            done
        fi
    done

    echo ""
    echo "=== Routes in ${PROJECT_CPD_INST_OPERATORS} ==="
    oc get routes -n "${PROJECT_CPD_INST_OPERATORS}"
fi

# ---
# Apply annotations and labels to each OpenSearch instance (dashboards, nodePools, PVCs)

if [[ ${#SERVICE_IDS[@]} -eq 0 ]]; then
    echo "[WARN] No OpenSearch service instances found. Skipping annotations/labels patch."
else
    for CLUSTER_NAME in "${SERVICE_IDS[@]}"; do
        echo ""
        echo "=== Applying annotations/labels to OpenSearch instance: ${CLUSTER_NAME} ==="

        ANNOTATIONS=$(oc get opensearchcluster "${CLUSTER_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.spec.general.annotations}')
        LABELS=$(oc get opensearchcluster "${CLUSTER_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.spec.nodePools[0].labels}')

        NODE_POOL_COUNT=$(oc get opensearchcluster "${CLUSTER_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.spec.nodePools}' | jq '. | length')

        NODEPOOL_PATCHES=""
        for i in $(seq 0 $(( NODE_POOL_COUNT - 1 ))); do
            NODEPOOL_PATCHES+=",{\"op\":\"add\",\"path\":\"/spec/nodePools/${i}/annotations\",\"value\":${ANNOTATIONS}}"
        done

        oc patch opensearchcluster "${CLUSTER_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" \
            --type='json' -p="[
  {\"op\":\"add\",\"path\":\"/spec/dashboards/annotations\",\"value\":${ANNOTATIONS}},
  {\"op\":\"add\",\"path\":\"/spec/dashboards/labels\",\"value\":${LABELS}}
  ${NODEPOOL_PATCHES}
]"
        echo "[OK] Patched dashboards and nodePools for ${CLUSTER_NAME}."

        for PVC in $(oc get pvc -n "${PROJECT_CPD_INST_OPERANDS}" -l "opster.io/opensearch-cluster=${CLUSTER_NAME}" -o jsonpath='{.items[*].metadata.name}'); do
            oc patch pvc "${PVC}" -n "${PROJECT_CPD_INST_OPERANDS}" \
                --type='merge' -p "{\"metadata\":{\"annotations\":${ANNOTATIONS},\"labels\":${LABELS}}}"
            echo "[OK] Patched PVC ${PVC}."
        done
    done
fi

# ---
# Grant kubeadmin and cpadmin the all_access role in each OpenSearch instance
# Fixes: "OpenSearch roles could not be retrieved" in CP4D UI

OS_ROLE_MAPPING_USERS=("kubeadmin" "cpadmin")

_os_ensure_role_mapping() {
    local url="$1" user="$2" pass="$3" principal="$4"

    local http_code
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
        -u "${user}:${pass}" \
        -X PATCH "${url}/_plugins/_security/api/rolesmapping/all_access" \
        -H 'Content-Type: application/json' \
        -d "[{\"op\":\"add\",\"path\":\"/backend_roles/-\",\"value\":\"${principal}\"}]")

    if [[ "${http_code}" == "200" ]]; then
        echo "[OK] ${principal} mapped to all_access (PATCH)."
        return
    fi

    echo "[INFO] PATCH returned ${http_code} for ${principal}. Attempting PUT."
    local existing merged
    existing=$(curl -sk -u "${user}:${pass}" \
        "${url}/_plugins/_security/api/rolesmapping/all_access" | \
        jq '.all_access.backend_roles // []')
    merged=$(echo "${existing}" | jq --arg p "${principal}" '. + [$p] | unique')
    http_code=$(curl -sk -o /dev/null -w "%{http_code}" \
        -u "${user}:${pass}" \
        -X PUT "${url}/_plugins/_security/api/rolesmapping/all_access" \
        -H 'Content-Type: application/json' \
        -d "{\"backend_roles\":${merged}}")
    if [[ "${http_code}" == "200" ]]; then
        echo "[OK] ${principal} mapped to all_access (PUT)."
    else
        echo "[ERROR] Failed to map ${principal} to all_access (HTTP ${http_code})."
    fi
}

if [[ ${#SERVICE_IDS[@]} -eq 0 ]]; then
    echo "[WARN] No OpenSearch service instances found. Skipping role mapping."
else
    for CLUSTER_NAME in "${SERVICE_IDS[@]}"; do
        echo ""
        echo "=== Granting all_access role mapping in OpenSearch instance: ${CLUSTER_NAME} ==="

        OS_ADMIN_SECRET="${CLUSTER_NAME}-user-secret"
        OS_ADMIN_USER=$(oc get secret "${OS_ADMIN_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
            -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || true)
        OS_ADMIN_PASS=$(oc get secret "${OS_ADMIN_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" \
            -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)

        if [[ -z "${OS_ADMIN_USER:-}" || -z "${OS_ADMIN_PASS:-}" ]]; then
            echo "[WARN] Could not retrieve admin credentials from secret ${OS_ADMIN_SECRET}. Skipping ${CLUSTER_NAME}."
            continue
        fi

        OS_HOST=$(oc get route "${CLUSTER_NAME}-backend" -n "${PROJECT_CPD_INST_OPERATORS}" \
            --no-headers -o custom-columns=HOST:.spec.host 2>/dev/null || true)

        if [[ -z "${OS_HOST:-}" ]]; then
            echo "[WARN] Could not resolve backend route for ${CLUSTER_NAME}. Skipping role mapping."
            continue
        fi

        OS_URL="https://${OS_HOST}"

        for PRINCIPAL in "${OS_ROLE_MAPPING_USERS[@]}"; do
            _os_ensure_role_mapping "${OS_URL}" "${OS_ADMIN_USER}" "${OS_ADMIN_PASS}" "${PRINCIPAL}"
        done
    done
fi

#### ---- the issue with the pull images was that it was using "icr.io" as a base pull prefix, rather than "cp.icr.io" which is required by the ibm_wxd_opensearch plugin.