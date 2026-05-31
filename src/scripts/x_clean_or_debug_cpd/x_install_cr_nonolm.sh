#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

eval "${CPDM_OC_LOGIN}"

# COMPONENT_LIST=(
#     "ccs"
# )

# COMPONENT_LIST_STRING=$(IFS=,; echo "${COMPONENT_LIST[*]}")
# COMPONENT_LIST_STRING="${COMPLETE_COMPONENT_LIST}"

COMPONENT="ccs"

PARAM_FILE_FLAG=()
if [[ -n "${INSTALL_OPTIONS}" ]]; then
    PARAM_FILE_FLAG=(--param-file="${CPD_CONFIG_PATH_CONTAINER}/${INSTALL_OPTIONS_FILE}")
fi

PATCH_FLAG=()
if [[ -n "${PATCH_ID}" ]]; then
    PATCH_FLAG=(--patch_id="${PATCH_ID}")
fi

cpd-cli manage install-components \
    --license_acceptance=true \
    --components=${COMPONENT} \
    --release=${VERSION} \
    --operator_ns=${PROJECT_CPD_INST_OPERATORS} \
    --instance_ns=${PROJECT_CPD_INST_OPERANDS} \
    --block_storage_class=${STG_CLASS_BLOCK} \
    --file_storage_class=${STG_CLASS_FILE} \
    --image_pull_prefix=${IMAGE_PULL_PREFIX} \
    --image_pull_secret=${IMAGE_PULL_SECRET} \
    "${PARAM_FILE_FLAG[@]}" \
    --upgrade=${UPDATE} \
    "${PATCH_FLAG[@]}"

# cpd-cli manage update-cr \
#     --component=${COMPONENT} \
#     --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
#     --cluster_component_ns=${PROJECT_CPD_INST_OPERATORS} \
#     "${PATCH_FLAG[@]}" \
#     --verbose

# cpd-cli manage apply-cr \
#     --license_acceptance=true \
#     --components=${COMPONENT_LIST_STRING} \
#     --release=${VERSION} \
#     --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
#     --block_storage_class=${STG_CLASS_BLOCK} \
#     --file_storage_class=${STG_CLASS_FILE} \
#     "${PARAM_FILE_FLAG[@]}" \
#     --upgrade=${UPDATE} \
#     --parallel_num=4 \
#     --verbose