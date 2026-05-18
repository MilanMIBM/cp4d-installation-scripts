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

# ZEN_VERSION mapping: 5.3.1 -> 6.4.0, 5.3.0 -> 6.3.0
case "${VERSION}" in
  5.3.1) export ZEN_VERSION="6.4.0" ;;
  5.3.0) export ZEN_VERSION="6.3.0" ;;
  *) echo "[ERROR] Unknown VERSION=${VERSION}, cannot determine ZEN_VERSION"; exit 1 ;;
esac

if [ "${IMAGE_PULL_PREFIX}" = "icr.io" ]; then
  cpd-cli manage install-cpd-config-ac \
    --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
else
  cpd-cli manage install-cpd-config-ac \
    --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
    --cpd_config_ac_image=${IMAGE_PULL_PREFIX}/cpopen/cpfs/zen-rsi-adm-controller:${ZEN_VERSION}-${IMAGE_ARCH}
fi

cpd-cli manage enable-cpd-config-ac \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
