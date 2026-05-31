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

    REPO_ROOT="$(cd "${SCRIPT_DIR}" && while [[ ! -f pyproject.toml ]]; do cd ..; done && pwd)"
    PULL_SECRET_FILE="${REPO_ROOT}/cp4d_config/pull-secret.dockerconfigjson"

    _raw_secret="$(oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' 2>/dev/null | base64 --decode)" || true

    if [[ -n "${_raw_secret}" ]]; then
        if echo "${_raw_secret}" | python3 -c "import sys, json; d=json.load(sys.stdin); exit(0 if 'icr.io' in d.get('auths',{}) else 1)" 2>/dev/null; then
            echo "[INFO] icr.io auth already present in openshift-config pull-secret - no patch needed."
            _patched="${_raw_secret}"
        else
            echo "[INFO] icr.io auth not found - patching pull-secret with cp.icr.io credentials."
            _cp_auth="$(echo "${_raw_secret}" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d['auths'].get('cp.icr.io',{}).get('auth',''))")"
            if [[ -z "${_cp_auth}" ]]; then
                echo "[WARN] cp.icr.io auth not found in pull-secret; skipping icr.io patch." >&2
                _patched="${_raw_secret}"
            else
                _patched="$(echo "${_raw_secret}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
cp_entry = d['auths']['cp.icr.io']
d['auths']['icr.io'] = cp_entry
print(json.dumps(d, indent=2))
")"
                _patched_b64="$(echo -n "${_patched}" | base64 | tr -d '\n')"
                oc patch secret pull-secret -n openshift-config \
                    --type=merge \
                    -p "{\"data\":{\".dockerconfigjson\":\"${_patched_b64}\"}}"
                echo "[INFO] pull-secret patched with icr.io auth."
            fi
        fi

        mkdir -p "$(dirname "${PULL_SECRET_FILE}")"
        echo "${_patched}" | python3 -c "import sys, json; print(json.dumps(json.load(sys.stdin), indent=2))" > "${PULL_SECRET_FILE}"
        echo "[INFO] pull-secret saved to ${PULL_SECRET_FILE}"
    else
        echo "[WARN] Could not retrieve pull-secret from openshift-config; skipping icr.io patch." >&2
    fi
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
