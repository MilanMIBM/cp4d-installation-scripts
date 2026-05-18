
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

create_project_if_not_exists() {
    local ns="$1"
    if oc get project "${ns}" &>/dev/null; then
        echo "[INFO] Project '${ns}' already exists, skipping."
    else
        oc new-project "${ns}"
    fi
}

[[ -n "${PROJECT_LICENSE_SERVICE}" ]] && create_project_if_not_exists "${PROJECT_LICENSE_SERVICE}"
[[ -n "${PROJECT_SCHEDULING_SERVICE}" ]] && create_project_if_not_exists "${PROJECT_SCHEDULING_SERVICE}"

[[ -n "${PROJECT_IBM_EVENTS}" ]] && create_project_if_not_exists "${PROJECT_IBM_EVENTS}"
[[ -n "${PROJECT_PRIVILEGED_MONITORING_SERVICE}" ]] && create_project_if_not_exists "${PROJECT_PRIVILEGED_MONITORING_SERVICE}"

[[ -n "${PROJECT_CPD_INST_OPERATORS}" ]] && create_project_if_not_exists "${PROJECT_CPD_INST_OPERATORS}"
[[ -n "${PROJECT_CPD_INST_OPERANDS}" ]] && create_project_if_not_exists "${PROJECT_CPD_INST_OPERANDS}"
