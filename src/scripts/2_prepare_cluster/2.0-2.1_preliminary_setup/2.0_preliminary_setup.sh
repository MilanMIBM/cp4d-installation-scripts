#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

"${CURRENT_DIR}/2.0.1_preliminary_project_setup.sh"
"${CURRENT_DIR}/2.0.2_cluster_component_case_download.sh"
"${CURRENT_DIR}/2.0.3_preliminary_secrets_setup.sh"
"${CURRENT_DIR}/2.1_apply_shared_cluster_CASE_packages.sh"
