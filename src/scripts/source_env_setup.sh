#!/bin/zsh
# Sourceable env setup - use from any script in src/scripts/*/: source "$(dirname $0)/../source_env_setup.sh"
# Guard against double-sourcing
[[ -n "${_CP4D_ENV_LOADED:-}" ]] && return 0
_CP4D_ENV_LOADED=1

_ENV_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export CONFIG_DIR="${_ENV_SETUP_DIR}/../../cp4d_config"
export SERVICE_INSTANCE_FILE_DIR="${_ENV_SETUP_DIR}/../../service_instances"
unset _ENV_SETUP_DIR

_sourced=()
_source_if_exists() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    local real; real="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
    for s in "${_sourced[@]:-}"; do [[ "$s" == "$real" ]] && return 0; done
    _sourced+=("$real")
    source "$real"
}

_source_if_exists "${CONFIG_DIR}/cpd_vars.sh"
_source_if_exists "${CONFIG_DIR}/cpd_instance_details.sh"
for _f in "${CONFIG_DIR}"/*.sh; do
    _source_if_exists "$_f"
done
unset _f _sourced
unset -f _source_if_exists

export CPD_CLI_MANAGE_WORKSPACE="$HOME/cpd-cli"
export PATH="$HOME/cpd-cli:$PATH"
export CPD_CLI_WORK_PATH="$HOME/cpd-cli/work"
export CPD_CLI_WORK_PATH_CONTAINER="/tmp/work"
export CPD_CONFIG_PATH_CONTAINER="/cp4d_config"

# Copy cp4d_config files into the work directory so the container can read them at /tmp/work/cp4d_config/
_CONFIG_WORK_DIR="${CPD_CLI_WORK_PATH}/cp4d_config"
mkdir -p "${_CONFIG_WORK_DIR}"
cp "${CONFIG_DIR}/"* "${_CONFIG_WORK_DIR}/" 2>/dev/null || true
unset _CONFIG_WORK_DIR

# Override CPD_CONFIG_PATH_CONTAINER to point at the copied location inside the container
export CPD_CONFIG_PATH_CONTAINER="/tmp/work/cp4d_config"
