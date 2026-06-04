#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

# -----------------------------------------------------------------------------
# Creates Software Hub custom cards that link to the instance routes of the
# data services prepped by the 5_prep_* scripts (MongoDB Ops Manager, DataStax
# Mission Control, OpenSearch).
#
# The card definitions live in src/helpers/custom_card_templates/ and are driven
# by build_instance_route_cards.py, which reads the route URLs the prep scripts
# exported into cp4d_config/cpd_instance_details.sh and calls the Custom cards
# API via softwarehub_custom_card_helpers.py.
#
# This script only runs when at least one of PREP_MONGODB, PREP_DATASTAX or
# PREP_OPENSEARCH is set to true in cpd_vars.sh - i.e. only builds cards for the
# services this installation actually prepped.
# -----------------------------------------------------------------------------

# Locate the repo root (marker: pyproject.toml).
REPO_ROOT="$(cd "${SCRIPT_DIR}" && while [[ ! -f pyproject.toml ]]; do cd ..; done && pwd)"
HELPERS_DIR="${REPO_ROOT}/src/helpers"
VARS_FILE="${REPO_ROOT}/cp4d_config/cpd_instance_details.sh"

# Normalise a flag value to a lowercase truthiness check.
_is_true() {
    case "${1:l}" in
        1|true|yes|y) return 0 ;;
        *) return 1 ;;
    esac
}

# Decide which services are enabled. Treat an unset flag as false.
PREP_MONGODB_ENABLED=false;   _is_true "${PREP_MONGODB:-false}"   && PREP_MONGODB_ENABLED=true
PREP_DATASTAX_ENABLED=false;  _is_true "${PREP_DATASTAX:-false}"  && PREP_DATASTAX_ENABLED=true
PREP_OPENSEARCH_ENABLED=false; _is_true "${PREP_OPENSEARCH:-false}" && PREP_OPENSEARCH_ENABLED=true

echo ""
echo "=== Software Hub custom cards (instance routes) ==="
echo "  PREP_MONGODB:   ${PREP_MONGODB_ENABLED}"
echo "  PREP_DATASTAX:  ${PREP_DATASTAX_ENABLED}"
echo "  PREP_OPENSEARCH:${PREP_OPENSEARCH_ENABLED}"
echo ""

if [[ "${PREP_MONGODB_ENABLED}" != "true" && \
      "${PREP_DATASTAX_ENABLED}" != "true" && \
      "${PREP_OPENSEARCH_ENABLED}" != "true" ]]; then
    echo "[INFO] None of PREP_MONGODB / PREP_DATASTAX / PREP_OPENSEARCH are true in cpd_vars.sh."
    echo "[INFO] No custom cards to build. Nothing to do."
    exit 0
fi

if [[ ! -f "${VARS_FILE}" ]]; then
    echo "[ERROR] Instance details file not found: ${VARS_FILE}"
    echo "[ERROR] Run the relevant 5_prep_* scripts first so the route URLs and"
    echo "        CPD admin credentials are written to cpd_instance_details.sh."
    exit 1
fi

# Pick the repo's virtualenv python if present, otherwise fall back to python3.
if [[ -x "${REPO_ROOT}/.venv/bin/python" ]]; then
    PYTHON="${REPO_ROOT}/.venv/bin/python"
else
    PYTHON="python3"
fi

echo "[INFO] Building custom cards from ${VARS_FILE##*/} using ${PYTHON}"
echo ""

# build_instance_route_cards.py imports its sibling helper modules, so run it
# with src/helpers as the working directory / import root.
( cd "${HELPERS_DIR}" && "${PYTHON}" build_instance_route_cards.py "${VARS_FILE}" )

echo ""
echo "=== Done ==="
