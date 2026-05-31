#!/bin/zsh
# Like source_env_setup.sh but also copies cp4d_config files into the cpd-cli work directory
# so they are accessible inside the container at CPD_CONFIG_PATH_CONTAINER.
# Guard against double-sourcing
[[ -n "${_CP4D_ENV_WITH_CONFIG_LOADED:-}" ]] && return 0
_CP4D_ENV_WITH_CONFIG_LOADED=1

_SETUP_WITH_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${_SETUP_WITH_CONFIG_DIR}/source_env_setup.sh"
unset _SETUP_WITH_CONFIG_DIR

# Copy cp4d_config files into the work directory so the container can read them at /tmp/work/cp4d_config/
_CONFIG_WORK_DIR="${CPD_CLI_WORK_PATH}/cp4d_config"
mkdir -p "${_CONFIG_WORK_DIR}"
cp "${CONFIG_DIR}/"* "${_CONFIG_WORK_DIR}/" 2>/dev/null || true
unset _CONFIG_WORK_DIR

# Override CPD_CONFIG_PATH_CONTAINER to point at the copied location inside the container
export CPD_CONFIG_PATH_CONTAINER="/tmp/work/cp4d_config"
