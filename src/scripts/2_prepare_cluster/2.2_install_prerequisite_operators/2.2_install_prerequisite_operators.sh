#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

"${CURRENT_DIR}/2.2.1_install_nvidia_node_discovery.sh"
"${CURRENT_DIR}/2.2.2_install_nvidia_gpu_operator.sh"
"${CURRENT_DIR}/2.2.3_install_openshift_ai_operator.sh"
"${CURRENT_DIR}/2.2.4_install_ibm_knative_eventing_operator.sh"
