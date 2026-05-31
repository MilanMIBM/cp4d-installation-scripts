#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

eval "${CPDM_OC_LOGIN}"

COMPONENT_LIST=(
    "ccs"
    "analyticsengine"
    "factsheet"
)

COMPONENT_LIST_STRING=$(IFS=,; echo "${COMPONENT_LIST[*]}")

echo "[INFO] Restarting components: ${COMPONENT_LIST_STRING} in ${PROJECT_CPD_INST_OPERANDS}"
cpd-cli manage restart \
    --components=${COMPONENT_LIST_STRING} \
    --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
    --verbose