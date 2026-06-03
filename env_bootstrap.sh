#!/bin/zsh
# =============================================================================
# env_bootstrap.sh - universal environment loader for cp4d-installation-scripts
# -----------------------------------------------------------------------------
# Purpose:
#   Provide a single, location-independent way for any script in this repo to
#   load the shared environment (source_env_setup.sh), no matter how deeply it
#   is nested or where it is moved to.
#
# How scripts use it (one line, near the top, after SCRIPT_DIR is defined):
#
#     _b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b
#
#   That snippet walks up the directory tree until it finds THIS file at the
#   repo root, then sources it. This file then locates and sources the shared
#   env (source_env_setup.sh) for you.
#
# Notes:
#   - Must be SOURCED, not executed: it exports variables into the caller.
#   - Safe to source multiple times (source_env_setup.sh guards itself via
#     _CP4D_ENV_LOADED).
#   - This file lives at the repo root and is the search marker, so moving the
#     numbered step scripts around never breaks env loading.
# =============================================================================

# Already loaded? Nothing to do.
[[ -n "${_CP4D_ENV_LOADED:-}" ]] && return 0

# Resolve the directory THIS file lives in (the repo root).
_BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# The shared env setup lives under src/scripts/.
_ENV_SETUP="${_BOOTSTRAP_DIR}/src/scripts/source_env_setup.sh"

if [[ -f "${_ENV_SETUP}" ]]; then
    source "${_ENV_SETUP}"
else
    echo "ERROR: env_bootstrap.sh could not find src/scripts/source_env_setup.sh under ${_BOOTSTRAP_DIR}" >&2
    unset _BOOTSTRAP_DIR _ENV_SETUP
    return 1 2>/dev/null || exit 1
fi

unset _BOOTSTRAP_DIR _ENV_SETUP
