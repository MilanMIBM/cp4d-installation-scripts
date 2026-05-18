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


CPD_INSTANCE_DETAILS="$(cpd-cli manage get-cpd-instance-details \
  --cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
  --get_admin_initial_credentials=true)"

echo "${CPD_INSTANCE_DETAILS}"

CPD_URL="$(echo "${CPD_INSTANCE_DETAILS}"       | grep 'CPD Url:'      | grep -oE '[^ ]+$' | tr -d '[:space:]')"
CPD_USERNAME="$(echo "${CPD_INSTANCE_DETAILS}"  | grep 'CPD Username:' | grep -oE '[^ ]+$' | tr -d '[:space:]')"
CPD_PASSWORD="$(echo "${CPD_INSTANCE_DETAILS}"  | grep 'CPD Password:' | grep -oE '[^ ]+$' | tr -d '[:space:]')"

REPO_ROOT="$(cd "${SCRIPT_DIR}" && while [[ ! -f pyproject.toml ]]; do cd ..; done && pwd)"
VARS_FILE="${REPO_ROOT}/cp4d_config/cpd_instance_details.sh"

cat > "${VARS_FILE}" <<EOF
# Written by $(basename $0) on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
export CPD_URL="https://${CPD_URL}"
export CPD_USERNAME="${CPD_USERNAME}"
export CPD_PASSWORD="${CPD_PASSWORD}"
EOF

echo "[INFO] CPD instance credentials written to $(basename ${VARS_FILE})"