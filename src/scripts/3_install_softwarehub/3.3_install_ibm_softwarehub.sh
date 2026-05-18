#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---
eval "${CPDM_OC_LOGIN}"

# Split SOFTWARE_HUB into cluster-scoped and instance-scoped components
HAS_LICENSING=false
HAS_SCHEDULER=false
INSTANCE_COMPONENTS=()

IFS=',' read -rA _all_components <<< "${SOFTWARE_HUB}"
for _c in "${_all_components[@]}"; do
    case "${_c}" in
        ibm-licensing) HAS_LICENSING=true ;;
        scheduler)     HAS_SCHEDULER=true ;;
        *)             INSTANCE_COMPONENTS+=("${_c}") ;;
    esac
done

PARAM_FILE_FLAG=()
if [[ -f "${CPD_CLI_WORK_PATH}/{INSTALL_OPTIONS_FILE}" ]]; then
    PARAM_FILE_FLAG=(--param-file=${CPD_CLI_WORK_PATH_CONTAINER}/{INSTALL_OPTIONS_FILE})
fi

# Install remaining instance-scoped components (e.g. cpfs, cpd_platform)
if (( ${#INSTANCE_COMPONENTS[@]} > 0 )); then
    for var in STG_CLASS_BLOCK STG_CLASS_FILE IMAGE_PULL_PREFIX IMAGE_PULL_SECRET; do
        if [[ -z "${(P)var:-}" ]]; then
            echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
            exit 1
        fi
    done
    INSTANCE_COMPONENTS_STR="${(j:,:)INSTANCE_COMPONENTS}"
    echo "[INFO] Running install-components for: ${INSTANCE_COMPONENTS_STR}"
    cpd-cli manage install-components \
        --license_acceptance=true \
        --components=${INSTANCE_COMPONENTS_STR} \
        --release=${VERSION} \
        --operator_ns=${PROJECT_CPD_INST_OPERATORS} \
        --instance_ns=${PROJECT_CPD_INST_OPERANDS} \
        --block_storage_class=${STG_CLASS_BLOCK} \
        --file_storage_class=${STG_CLASS_FILE} \
        --image_pull_prefix=${IMAGE_PULL_PREFIX} \
        --image_pull_secret=${IMAGE_PULL_SECRET} \
        "${PARAM_FILE_FLAG[@]}" \
        --run_storage_tests=false
fi