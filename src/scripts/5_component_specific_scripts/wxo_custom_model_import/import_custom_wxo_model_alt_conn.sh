#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

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
# WHY THIS "ALT CONN" VARIANT EXISTS
# ----------------------------------
# The standard import_custom_wxo_model.sh registers ICA as a *virtual model* with
# a `key_value` connection. That path CANNOT be member-scoped, by design:
#   * Virtual models route through the AI Gateway, and the docs state plainly:
#     "The AI Gateway supports only key-value connections."
#   * key_value connections support `-t team` only - member is NOT supported
#     (connections/overview -> "Support for member vs team": Key-Value = team only).
#   * The only model-level auth that supports member is OAuth client-credentials
#     (provider `openai-oauth2-client-creds`), which needs a SEPARATE OAuth token
#     endpoint. ICA has none: per its OpenAPI spec it authenticates with a STATIC
#     developer API key sent as `Authorization: Bearer sk-...` (securityScheme
#     DeveloperApiKey: http/bearer). There is no token_url to exchange.
#
# So a per-user (member) credential is simply not expressible at the virtual-model
# layer for ICA. To get true per-user keys we drop the virtual-model approach and
# instead expose ICA as an OPENAPI TOOL backed by a BEARER connection:
#   * Bearer connections DO support `-t member` (connections/overview matrix).
#   * For an OpenAPI tool, a Bearer connection injects exactly the header ICA
#     wants: `Authorization: Bearer {token}`
#     (associate_connection_to_tool/openapi_connections -> "Bearer Connections").
#   * With `-t member`, each user is prompted in chat for THEIR OWN ICA key; the
#     builder's token below only seeds a default and may be empty.
#
# Trade-off vs the standard script: ICA is reachable as a tool (the agent calls
# the chat-completions operation), not as a model in the LLM dropdown. That is the
# cost of getting genuine per-user authentication, which the model path forbids.

# --- The ICA developer API key (the Bearer token) ---
# Sourced via cpd_vars.sh -> ICA_APIKEY. For a member connection this is only the
# seeded default and MAY be empty (each user supplies their own in chat). For a
# team connection it is the single shared key and must be set.
APIKEY="${ICA_APIKEY:-}"

# Path to the ICA OpenAPI spec that defines the tool's operations.
ICA_SPEC_FILE="${ICA_SPEC_FILE:-${CURRENT_DIR}/specs/ica-openapi-spec.yaml}"

# app_id of the connection, and the tool app-id it is bound to.
CONN_APP_ID="ica_credentials"

# --- Connection scope: team-wide vs personal/member ---
# false -> '-t member' : each user supplies their own ICA key in chat (the point
#                        of this script).
# true  -> '-t team'   : one shared key set here for all users.
TEAM_CONNECTION=false
if [[ "${TEAM_CONNECTION}" == true ]]; then
  CONN_TYPE=team
else
  CONN_TYPE=member
fi
echo "[CONN] scope: -t ${CONN_TYPE} (kind: bearer)"

# A team connection with no token cannot authenticate anyone to ICA.
if [[ "${CONN_TYPE}" == team && -z "${APIKEY}" ]]; then
  echo "[ERROR] TEAM_CONNECTION=true but ICA_APIKEY is empty - check cp4d_config/cpd_vars.sh." >&2
  exit 1
fi

if [[ ! -f "${ICA_SPEC_FILE}" ]]; then
  echo "[ERROR] ICA OpenAPI spec not found at ${ICA_SPEC_FILE}." >&2
  exit 1
fi

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

# Show a truncated token so the user can confirm which value is in use without
# leaking the full secret to the terminal/logs.
_ak="${(e)APIKEY}"
if [[ -z "${_ak}" ]]; then
  echo "[TOKEN] (empty - member users will supply their own)"
elif (( ${#_ak} <= 8 )); then
  echo "[TOKEN] **** (${#_ak} chars)"
else
  echo "[TOKEN] ${_ak[1,4]}...${_ak[-4,-1]} (${#_ak} chars)"
fi
unset _ak

# Add the connection; if one with this app-id already exists, delete it and re-add.
if ! orchestrate connections add -a "${CONN_APP_ID}"; then
  echo "[CONN] '${CONN_APP_ID}' already exists - removing and re-adding"
  orchestrate connections remove -a "${CONN_APP_ID}"
  orchestrate connections add -a "${CONN_APP_ID}"
fi
for _env in "${CONFIG_ENVS[@]}"; do
  # Configure the env as a Bearer connection (member-capable, injects
  # `Authorization: Bearer {token}` for the bound OpenAPI tool).
  orchestrate connections configure -a "${CONN_APP_ID}" --env "${_env}" -k bearer -t "${CONN_TYPE}"
  # Seed the bearer token. For a member connection this is just the default; each
  # user can still set their own at runtime. Skipped when empty for member scope.
  if [[ -n "${APIKEY}" ]]; then
    orchestrate connections set-credentials -a "${CONN_APP_ID}" --env "${_env}" --token "${APIKEY}"
  else
    echo "[CONN] no seed token for env '${_env}' (member users supply their own)"
  fi
done

# Import ICA as an OpenAPI tool bound to the Bearer connection. The tool exposes
# the spec's operations (chat completions, model listing, files, collections);
# the connection supplies the per-user Authorization header.
_tool_ok=0
if orchestrate tools import -k openapi -f "${ICA_SPEC_FILE}" -a "${CONN_APP_ID}"; then
  _tool_ok=1
else
  echo "[TOOL] import failed (likely already exists) - re-importing to update"
  # A re-import with the same operationIds upserts the tool; no explicit remove
  # is required, but retry once in case the first attempt left it partially set.
  if orchestrate tools import -k openapi -f "${ICA_SPEC_FILE}" -a "${CONN_APP_ID}"; then
    _tool_ok=1
  fi
fi

echo "----------------------------------------------------------------------"
if (( _tool_ok == 1 )); then
  echo "[SUCCESS] ICA OpenAPI tool imported (bearer connection '${CONN_APP_ID}', scope: ${CONN_TYPE}, env(s): ${CONFIG_ENVS[*]})"
  echo "          Add the tool to an agent; member users will be prompted for their own ICA key."
else
  echo "[FAILURE] ICA OpenAPI tool could NOT be imported - see errors above" >&2
fi
echo "----------------------------------------------------------------------"
(( _tool_ok == 1 )) || exit 1