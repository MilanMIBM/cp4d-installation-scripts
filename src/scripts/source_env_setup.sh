#!/bin/zsh
# Sourceable env setup - use from any script in src/scripts/*/: source "$(dirname $0)/../source_env_setup.sh"
# Guard against double-sourcing
[[ -n "${_CP4D_ENV_LOADED:-}" ]] && return 0
_CP4D_ENV_LOADED=1

_ENV_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CONFIG_DIR="${_ENV_SETUP_DIR}/../../cp4d_config"
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
# The container mounts CPD_CLI_WORK_PATH at /tmp/work; use this for --param-file flags
export CPD_CLI_WORK_PATH_CONTAINER="/tmp/work"