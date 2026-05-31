#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../../source_env_setup.sh"
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

"${CURRENT_DIR}/3.2_set_up_cpd_admin.sh"
"${CURRENT_DIR}/3.3_install_ibm_softwarehub.sh"
"${CURRENT_DIR}/3.3.1_get_instance_creds.sh"
"${CURRENT_DIR}/3.3.2_softwarehub_admission_controller.sh"
"${CURRENT_DIR}/3.4_apply_entitlements.sh"
