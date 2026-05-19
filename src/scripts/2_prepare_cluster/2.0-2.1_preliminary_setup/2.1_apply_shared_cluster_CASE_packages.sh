
#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"


PATCH_FLAG=()
if [[ -n "${PATCH_ID}" ]]; then
    PATCH_FLAG=(--patch_id=${PATCH_ID})
fi

PARAM_FILE_FLAG=()
if [[ -f "${CPD_CLI_WORK_PATH}/{INSTALL_OPTIONS_FILE}" ]]; then
    PARAM_FILE_FLAG=(--param-file=${CPD_CLI_WORK_PATH_CONTAINER}/{INSTALL_OPTIONS_FILE})
fi

# ---
eval "${CPDM_OC_LOGIN}"

# Split SOFTWARE_HUB into cluster-scoped and instance-scoped components
HAS_LICENSING=false
HAS_SCHEDULER=false
INSTANCE_COMPONENTS=()

IFS=',' read -ra _all_components <<< "${SOFTWARE_HUB}"
for _c in "${_all_components[@]}"; do
    case "${_c}" in
        ibm-licensing) HAS_LICENSING=true ;;
        scheduler)     HAS_SCHEDULER=true ;;
        *)             INSTANCE_COMPONENTS+=("${_c}") ;;
    esac
done

cpd-cli manage authorize-instance-topology \
    --cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
    --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}


# Apply cluster-wide components (License Service + cert-manager) if ibm-licensing is listed
if [[ "${HAS_LICENSING}" == true ]]; then
    echo "[INFO] Running apply-cluster-components (ibm-licensing)"
    cpd-cli manage apply-cluster-components \
        --release=${VERSION} \
        --license_acceptance=true \
        --licensing_ns=${PROJECT_LICENSE_SERVICE} \
        --case_download=true \
        "${PATCH_FLAG[@]}"

fi

# Apply the scheduling service if scheduler is listed
if [[ "${HAS_SCHEDULER}" == true ]]; then
    echo "[INFO] Running apply-scheduler (scheduler)"
    cpd-cli manage apply-scheduler \
        --release=${VERSION} \
        --license_acceptance=true \
        --scheduler_ns=${PROJECT_SCHEDULING_SERVICE} \
        --image_pull_prefix=${IMAGE_PULL_PREFIX} \
        --image_pull_secret=${IMAGE_PULL_SECRET} \
        --case_download=true \
        "${PARAM_FILE_FLAG[@]}" \
        "${PATCH_FLAG[@]}"
fi