#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---

for var in COMPONENTS VERSION PROJECT_CPD_INST_OPERATORS PROJECT_CPD_INST_OPERANDS STG_CLASS_BLOCK STG_CLASS_FILE IMAGE_PULL_PREFIX IMAGE_PULL_SECRET; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${CPDM_OC_LOGIN}"

SKIP_COMPONENTS_FLAG=()
if [[ -n "${COMPONENTS_TO_SKIP:-}" ]]; then
    SKIP_COMPONENTS_FLAG=(--skip_components="${COMPONENTS_TO_SKIP}")
fi

PARAM_FILE_FLAG=()
if [[ -n "${INSTALL_OPTIONS}" ]]; then
    PARAM_FILE_FLAG=(--param-file="${CPD_CLI_WORK_PATH_CONTAINER}/${INSTALL_OPTIONS_FILE}")
fi

PATCH_FLAG=()
if [[ -n "${PATCH_ID}" ]]; then
    PATCH_FLAG=(--patch_id="${PATCH_ID}")
fi


cpd-cli manage install-components \
    --license_acceptance=true \
    --components=${CPD_COMPONENTS} \
    --release=${VERSION} \
    --operator_ns=${PROJECT_CPD_INST_OPERATORS} \
    --instance_ns=${PROJECT_CPD_INST_OPERANDS} \
    --block_storage_class=${STG_CLASS_BLOCK} \
    --file_storage_class=${STG_CLASS_FILE} \
    --image_pull_prefix=${IMAGE_PULL_PREFIX} \
    --image_pull_secret=${IMAGE_PULL_SECRET} \
    "${PARAM_FILE_FLAG[@]}" \
    "${SKIP_COMPONENTS_FLAG[@]}" \
    --upgrade=${UPDATE} \
    "${PATCH_FLAG[@]}"