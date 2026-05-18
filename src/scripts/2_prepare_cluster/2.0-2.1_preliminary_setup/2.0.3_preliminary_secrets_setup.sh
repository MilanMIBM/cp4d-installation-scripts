
#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"

# --- Create projects in the cluster
eval "${OC_LOGIN}"

# --- Image pull secret for scheduling service
if [[ -n "${IMAGE_PULL_SECRET:-}" && -n "${IMAGE_PULL_CREDENTIALS:-}" && -n "${PROJECT_SCHEDULING_SERVICE:-}" ]]; then
    if [[ -n "${PRIVATE_REGISTRY_LOCATION:-}" ]]; then
        cat <<EOF > dockerconfig.json
{
    "auths": {
        "${PRIVATE_REGISTRY_LOCATION}": {
            "auth": "${IMAGE_PULL_CREDENTIALS}"
        }
    }
}
EOF
    else
        cat <<EOF > dockerconfig.json
{
    "auths": {
        "cp.icr.io": {
            "auth": "${IMAGE_PULL_CREDENTIALS}"
        },
        "icr.io": {
            "auth": "${IMAGE_PULL_CREDENTIALS}"
        }
    }
}
EOF
    fi

    echo "[INFO] dockerconfig.json contents:"
    cat dockerconfig.json

    oc create secret docker-registry "${IMAGE_PULL_SECRET}" \
        --from-file ".dockerconfigjson=dockerconfig.json" \
        --namespace="${PROJECT_SCHEDULING_SERVICE}" \
        --dry-run=client -o yaml | oc apply -f -

    oc create secret docker-registry "${IMAGE_PULL_SECRET}" \
        --from-file ".dockerconfigjson=dockerconfig.json" \
        --namespace="${PROJECT_CPD_INST_OPERATORS}" \
        --dry-run=client -o yaml | oc apply -f -

    oc create secret docker-registry "${IMAGE_PULL_SECRET}" \
        --from-file ".dockerconfigjson=dockerconfig.json" \
        --namespace="${PROJECT_CPD_INST_OPERANDS}" \
        --dry-run=client -o yaml | oc apply -f -

    oc create secret docker-registry ibm-entitlement-key \
        --from-file ".dockerconfigjson=dockerconfig.json" \
        --namespace="${PROJECT_SCHEDULING_SERVICE}" \
        --dry-run=client -o yaml | oc apply -f -

    oc create secret docker-registry ibm-entitlement-key \
        --from-file ".dockerconfigjson=dockerconfig.json" \
        --namespace="${PROJECT_CPD_INST_OPERANDS}" \
        --dry-run=client -o yaml | oc apply -f -

    oc create secret docker-registry ibm-entitlement-key \
        --from-file ".dockerconfigjson=dockerconfig.json" \
        --namespace="${PROJECT_CPD_INST_OPERATORS}" \
        --dry-run=client -o yaml | oc apply -f -


    rm -f dockerconfig.json
fi