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

_has_icr=false
_has_private=false
_missing_private=()

[[ -n "${IBM_ENTITLEMENT_KEY:-}" ]] && _has_icr=true

[[ -z "${PRIVATE_REGISTRY_LOCATION:-}" ]]    && _missing_private+=(PRIVATE_REGISTRY_LOCATION)
[[ -z "${PRIVATE_REGISTRY_PULL_USER:-}" ]]   && _missing_private+=(PRIVATE_REGISTRY_PULL_USER)
[[ -z "${PRIVATE_REGISTRY_PULL_PASSWORD:-}" ]] && _missing_private+=(PRIVATE_REGISTRY_PULL_PASSWORD)
(( ${#_missing_private[@]} == 0 )) && _has_private=true

if ! $_has_icr && ! $_has_private; then
    echo "[ERROR] No credentials configured. Set IBM_ENTITLEMENT_KEY for the IBM registry," \
        "or set PRIVATE_REGISTRY_LOCATION, PRIVATE_REGISTRY_PULL_USER, and PRIVATE_REGISTRY_PULL_PASSWORD for a private registry." >&2
    exit 1
fi

if $_has_icr; then
    cpd-cli manage add-icr-cred-to-global-pull-secret \
        --entitled_registry_key=${IBM_ENTITLEMENT_KEY}
fi

if $_has_private; then
    cpd-cli manage add-cred-to-global-pull-secret \
        --registry=${PRIVATE_REGISTRY_LOCATION} \
        --registry_pull_user=${PRIVATE_REGISTRY_PULL_USER} \
        --registry_pull_password=${PRIVATE_REGISTRY_PULL_PASSWORD}
elif (( ${#_missing_private[@]} < 3 )); then
    echo "[ERROR] Private registry credentials incomplete. Missing: ${_missing_private[*]}" >&2
    exit 1
fi
