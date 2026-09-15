#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail
# Ensure glob qualifiers (.N) work even if the invoking shell disabled them.
setopt bare_glob_qual null_glob

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# (legacy hardcoded sourcing - replaced by universal crawl below)
# source "${SCRIPT_DIR}/../source_env_setup.sh"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b
CURRENT_DIR="$(cd "$(dirname "$0")" && pwd)"

# This script lives in src/scripts/x_full_quick_install_script/, so the numbered
# step folders are one level up, in src/scripts/.
SCRIPTS_ROOT="$(cd "${CURRENT_DIR}/.." && pwd)"

# --- Activate the watsonx Orchestrate environment before any orchestrate calls ---
# Use CURRENT_DIR (re-derived after env load): sourcing cpd_vars.sh clobbers SCRIPT_DIR.
"${CURRENT_DIR}/activate_wxo_environment.sh"

# ---
# Expand the real key from the environment (sourced via cpd_vars.sh -> ICA_APIKEY).
# NOTE: must be double-quoted/unquoted expansion - single quotes would store the
# literal string '${ICA_APIKEY}', which ICA rejects with "Invalid icaKey".
# May be empty for a personal/member connection (each user supplies their own).
APIKEY="${ICA_APIKEY:-}"
MODELS_DIR="${CURRENT_DIR}/models"

# --- Connection scope: team-wide vs personal/member ---
# true  -> '-t team'   : one shared credential set by the builder for all users.
# false -> '-t member' : each user supplies their own credential; the builder's
#                        value (even if empty) just seeds the api_key field so it
#                        is visible/known to the team.
TEAM_CONNECTION=false
if [[ "${TEAM_CONNECTION}" == true ]]; then
  CONN_TYPE=team
else
  CONN_TYPE=member
fi
echo "[CONN] scope: -t ${CONN_TYPE}"

# A team connection with no api_key would leave ICA with an "Invalid icaKey".
if [[ "${CONN_TYPE}" == team && -z "${APIKEY}" ]]; then
  echo "[ERROR] TEAM_CONNECTION=true but ICA_APIKEY is empty - check cp4d_config/cpd_vars.sh." >&2
  exit 1
fi

# Show a truncated APIKEY so the user can confirm which value is in use without
# leaking the full secret to the terminal/logs.
_ak="${(e)APIKEY}"
if [[ -z "${_ak}" ]]; then
  echo "[APIKEY] (empty)"
elif (( ${#_ak} <= 8 )); then
  echo "[APIKEY] **** (${#_ak} chars)"
else
  echo "[APIKEY] ${_ak[1,4]}...${_ak[-4,-1]} (${#_ak} chars)"
fi
unset _ak

# --- Which connection environment(s) to configure credentials for ---
# Set both true to push credentials to draft and live; set one false to skip it.
DRAFT_CONFIG=true
LIVE_CONFIG=true

typeset -a CONFIG_ENVS
[[ "${DRAFT_CONFIG}" == true ]] && CONFIG_ENVS+=(draft)
[[ "${LIVE_CONFIG}" == true ]] && CONFIG_ENVS+=(live)
if (( ${#CONFIG_ENVS} == 0 )); then
  echo "[ERROR] Both DRAFT_CONFIG and LIVE_CONFIG are false - nothing to configure." >&2
  exit 1
fi
echo "[CONN] target env(s): ${CONFIG_ENVS[*]}"

# --- Default connection (app-id) used for any model not overridden below ---
DEFAULT_APP_ID='model_credentials'
DEFAULT_CREDENTIAL="api_key=${APIKEY}"

# --- Per-model app-id overrides ---
# Map a relative path under models/ to the app-id (connection) it should use.
# The key can be a subfolder (applies to every yaml inside it) or a specific
# yaml file. Anything not listed here falls back to DEFAULT_APP_ID.
#   Examples:
#     APP_ID_OVERRIDES[ica]='openai_credentials'
#     APP_ID_OVERRIDES[ica/claude-haiku-4-5.yaml]='openai_credentials'
typeset -A APP_ID_OVERRIDES
APP_ID_OVERRIDES[ica]='openai_credentials'

# --- Track which connections we've already created so we set them up once ---
typeset -A CONNECTIONS_DONE

# Ensure a key_value connection (team or member) exists and holds the default
# credential. The api_key field is always seeded - empty for member if unset.
ensure_connection() {
  local app_id="$1"
  [[ -n "${CONNECTIONS_DONE[$app_id]:-}" ]] && return 0
  echo "[CONN] setting up connection '${app_id}'"
  # Add the connection; if one with this app-id already exists, delete it and re-add.
  if ! orchestrate connections add -a "${app_id}"; then
    echo "[CONN] '${app_id}' already exists - removing and re-adding"
    orchestrate connections remove -a "${app_id}"
    orchestrate connections add -a "${app_id}"
  fi
  for _env in "${CONFIG_ENVS[@]}"; do
    orchestrate connections configure -a "${app_id}" --env "${_env}" -k key_value -t "${CONN_TYPE}"
    # DEFAULT_CREDENTIAL always carries 'api_key=...' so the field exists even if empty.
    orchestrate connections set-credentials -a "${app_id}" --env "${_env}" -e "${DEFAULT_CREDENTIAL}"
  done
  CONNECTIONS_DONE[$app_id]=1
}

# Resolve the app-id for a given yaml, given its path relative to MODELS_DIR.
# Prefer the most specific match: exact file first, then its parent folder(s).
resolve_app_id() {
  local rel="$1"
  # exact file match
  if [[ -n "${APP_ID_OVERRIDES[$rel]:-}" ]]; then
    echo "${APP_ID_OVERRIDES[$rel]}"
    return 0
  fi
  # walk up the directory components looking for a folder override
  local dir="${rel:h}"
  while [[ "${dir}" != "." && "${dir}" != "/" ]]; do
    if [[ -n "${APP_ID_OVERRIDES[$dir]:-}" ]]; then
      echo "${APP_ID_OVERRIDES[$dir]}"
      return 0
    fi
    dir="${dir:h}"
  done
  echo "${DEFAULT_APP_ID}"
}

# --- Walk every yaml under models/ and import it ---
found=0
typeset -a SUCCEEDED FAILED
for yaml in "${MODELS_DIR}"/**/*.{yaml,yml}(N); do
  (( found++ )) || true
  rel="${yaml#${MODELS_DIR}/}"
  app_id="$(resolve_app_id "${rel}")"
  ensure_connection "${app_id}"
  echo "[IMPORT] ${rel} -> --app-id ${app_id}"
  # Import the model; if it already exists (409 conflict), remove it and re-import.
  # The 'name:' field in the spec is e.g. 'openai/claude-haiku-4-5', but the model
  # is registered (and must be removed) under the 'virtual-model/' prefix.
  model_name="$(awk -F': *' '/^name:/{print $2; exit}' "${yaml}")"
  registered_name="virtual-model/${model_name}"
  if orchestrate models import --file "${yaml}" --app-id "${app_id}"; then
    SUCCEEDED+=("${rel}")
  else
    echo "[IMPORT] failed (likely already exists) - removing '${registered_name}' and re-importing"
    orchestrate models remove -n "${registered_name}" || true
    if orchestrate models import --file "${yaml}" --app-id "${app_id}"; then
      SUCCEEDED+=("${rel}")
    else
      FAILED+=("${rel}")
    fi
  fi
done

echo "======================================================================"
echo "[SUMMARY] model upload (env(s): ${CONFIG_ENVS[*]})"
if (( found == 0 )); then
  echo "  [WARN] no .yaml/.yml model files found under ${MODELS_DIR}"
else
  echo "  succeeded: ${#SUCCEEDED} / ${found}"
  for _m in "${SUCCEEDED[@]}"; do echo "    [OK]   ${_m}"; done
  for _m in "${FAILED[@]}";    do echo "    [FAIL] ${_m}"; done
fi
echo "======================================================================"

# Non-zero exit if any model failed, so callers/CI can detect it.
(( ${#FAILED} == 0 )) || exit 1
