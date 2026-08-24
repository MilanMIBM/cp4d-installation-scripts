#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# (legacy hardcoded sourcing - replaced by universal crawl below)
# source "${SCRIPT_DIR}/../../source_env_setup.sh"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Run an optional step, skipping it if the script is absent. Several component
# scripts (wxo, wxd/OpenSearch) were removed when the install was streamlined,
# but the flags that gate them may still be set in an existing cpd_vars.sh - a
# missing optional script must not abort a multi-hour install.
run_optional_step() {
    local _script="${CURRENT_DIR}/$1"
    if [[ ! -f "${_script}" ]]; then
        echo "[WARN] Optional step $1 not found - skipping."
        return 0
    fi
    if [[ ! -x "${_script}" ]]; then
        chmod +x "${_script}" 2>/dev/null || true
    fi
    "${_script}"
}

# Required steps stay unguarded: if these are missing, the install is broken and
# should fail loudly rather than silently produce an incomplete deployment.
"${CURRENT_DIR}/4.1_install_components.sh"
if [[ "${PREP_WXO:-}" == "true" ]]; then
    run_optional_step "4.0_wxo_install_preverification.sh"
fi
if [[ "${PREP_OPENSEARCH:-}" == "true" ]]; then
    run_optional_step "4.1.1_inst_wxd_opensearch.sh"
fi
"${CURRENT_DIR}/4.2_cpd_profile.sh"