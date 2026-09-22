#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

# ---

for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS PREP_DATASTAX; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

#---------------------------------------------------------------------------
##### DataStax HCD - create the default keyspace
#####
##### Both 5_prep_datastax_mc.sh and 5_prep_datastax_cql_gateway.sh export
##### DATASTAX_HCD_KEYSPACE / DATASTAX_CQL_KEYSPACE = "default_keyspace", but
##### nothing actually creates it - a fresh HCD datacenter ships with system
##### keyspaces only. This script closes that gap.
#####
##### It drives the DataApi (HTTP/JSON on the dataapi Route) rather than cqlsh,
##### because the DataApi is set up by default and needs no exec into a pod.
##### The Data API command surface is a single POST to <endpoint>/v1 with the
##### command as the JSON key: findKeyspaces / createKeyspace / dropKeyspace.
#####
##### Creation is skipped when the keyspace is already present.
#---------------------------------------------------------------------------

KEYSPACE_NAME="${DATASTAX_HCD_KEYSPACE:-default_keyspace}"

# Discover all CassandraDatacenter instance names in the operands namespace
DC_NAMES=($(oc get cassandradatacenters.cassandra.datastax.com -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.items[*].metadata.name}'))

if [[ ${#DC_NAMES[@]} -eq 0 ]]; then
    echo "Error: No CassandraDatacenter instances found in namespace ${PROJECT_CPD_INST_OPERANDS}."
    exit 1
fi

_PRIMARY_DC="${DC_NAMES[1]}"
_CLUSTER_NAME="datastax${_PRIMARY_DC//[^0-9]/}"
echo "[INFO] Target datacenter: ${_PRIMARY_DC} (cluster ${_CLUSTER_NAME})"

# --- resolve the DataApi endpoint -----------------------------------------
# 5_prep_datastax_mc.sh creates this edge Route; fall back to it by name.
_DATAAPI_ROUTE_NAME="${_PRIMARY_DC}-dataapi"
_DATAAPI_HOST="$(oc get route "${_DATAAPI_ROUTE_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
if [[ -z "${_DATAAPI_HOST}" ]]; then
    echo "Error: Route '${_DATAAPI_ROUTE_NAME}' not found in ${PROJECT_CPD_INST_OPERANDS}."
    echo "       Run 5_prep_datastax_mc.sh first - it creates the DataApi and its Route."
    exit 1
fi
DATAAPI_ENDPOINT="https://${_DATAAPI_HOST}"
echo "[INFO] DataApi endpoint: ${DATAAPI_ENDPOINT}"

# Confirm the DataApi is actually serving before firing commands at it.
_DATAAPI_READY="$(oc get dataapi.missioncontrol.datastax.com "${_PRIMARY_DC}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
if [[ "${_DATAAPI_READY}" != "True" ]]; then
    echo "[WARN] DataApi '${_PRIMARY_DC}' is not reporting Ready; attempting the call anyway." >&2
fi

# --- build the Data API token from the datacenter superuser ---------------
# The Data API expects the Cassandra-style token: Cassandra:<b64 user>:<b64 pass>
_SUPERUSER_SECRET="${_CLUSTER_NAME}-superuser"
DATASTAX_USER="" DATASTAX_PASSWORD=""
for (( _attempt=1; _attempt<=5; _attempt++ )); do
    DATASTAX_USER="$(oc get secret "${_SUPERUSER_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode || true)"
    DATASTAX_PASSWORD="$(oc get secret "${_SUPERUSER_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || true)"
    [[ -n "${DATASTAX_USER}" && -n "${DATASTAX_PASSWORD}" ]] && break
    _delay=$(( _attempt * 10 ))
    echo "[WARN] Secret '${_SUPERUSER_SECRET}' is missing username/password, retrying in ${_delay}s (attempt ${_attempt}/5)..." >&2
    sleep "${_delay}"
done
if [[ -z "${DATASTAX_USER}" || -z "${DATASTAX_PASSWORD}" ]]; then
    echo "Error: could not read '${_SUPERUSER_SECRET}' in ${PROJECT_CPD_INST_OPERANDS}."
    exit 1
fi

DATAAPI_TOKEN="Cassandra:$(printf %s "${DATASTAX_USER}" | base64):$(printf %s "${DATASTAX_PASSWORD}" | base64)"

# --- helper: POST a Data API command --------------------------------------
_dataapi_cmd() {
    curl -sS -k -X POST "${DATAAPI_ENDPOINT}/v1" \
        -H "Token: ${DATAAPI_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$1"
}

# --- only create the keyspace when it is not already present --------------
echo "[INFO] Checking for existing keyspaces..."
_FIND_RESPONSE="$(_dataapi_cmd '{"findKeyspaces":{}}')"

if [[ -z "${_FIND_RESPONSE}" ]]; then
    echo "Error: no response from the DataApi at ${DATAAPI_ENDPOINT}/v1."
    exit 1
fi

if echo "${_FIND_RESPONSE}" | jq -e '.errors' >/dev/null 2>&1; then
    echo "Error: DataApi returned an error on findKeyspaces:"
    echo "${_FIND_RESPONSE}" | jq '.errors'
    exit 1
fi

echo "[INFO] Existing keyspaces: $(echo "${_FIND_RESPONSE}" | jq -r '.status.keyspaces | join(", ")')"

if echo "${_FIND_RESPONSE}" | jq -e --arg ks "${KEYSPACE_NAME}" '.status.keyspaces | index($ks)' >/dev/null 2>&1; then
    echo "[INFO] Keyspace '${KEYSPACE_NAME}' already exists - skipping creation."
else
    # Replicate across every rack of the datacenter. A single-node demo DC
    # therefore gets RF=1, which is what NetworkTopologyStrategy wants here;
    # SimpleStrategy is not appropriate for a named datacenter.
    _DC_SIZE="$(oc get cassandradatacenters.cassandra.datastax.com "${_PRIMARY_DC}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.spec.size}' 2>/dev/null || echo 1)"
    _RF="${DATASTAX_KEYSPACE_RF:-}"
    if [[ -z "${_RF}" ]]; then
        if (( _DC_SIZE >= 3 )); then _RF=3; else _RF="${_DC_SIZE}"; fi
    fi
    echo "[INFO] Creating keyspace '${KEYSPACE_NAME}' (datacenter ${_PRIMARY_DC}, size ${_DC_SIZE}, RF ${_RF})..."

    _CREATE_BODY="$(jq -nc \
        --arg ks "${KEYSPACE_NAME}" \
        --arg dc "${_PRIMARY_DC}" \
        --argjson rf "${_RF}" \
        '{createKeyspace:{name:$ks,options:{replication:({class:"NetworkTopologyStrategy"} + {($dc):$rf})}}}')"

    _CREATE_RESPONSE="$(_dataapi_cmd "${_CREATE_BODY}")"

    if echo "${_CREATE_RESPONSE}" | jq -e '.errors' >/dev/null 2>&1; then
        echo "Error: failed to create keyspace '${KEYSPACE_NAME}':"
        echo "${_CREATE_RESPONSE}" | jq '.errors'
        exit 1
    fi

    if [[ "$(echo "${_CREATE_RESPONSE}" | jq -r '.status.ok // empty')" != "1" ]]; then
        echo "Error: unexpected response creating keyspace '${KEYSPACE_NAME}':"
        echo "${_CREATE_RESPONSE}"
        exit 1
    fi

    echo "[INFO] Keyspace '${KEYSPACE_NAME}' created."
fi

# --- verify ---------------------------------------------------------------
_VERIFY="$(_dataapi_cmd '{"findKeyspaces":{}}')"
if echo "${_VERIFY}" | jq -e --arg ks "${KEYSPACE_NAME}" '.status.keyspaces | index($ks)' >/dev/null 2>&1; then
    echo "[INFO] Verified: keyspace '${KEYSPACE_NAME}' is present."
else
    echo "Error: keyspace '${KEYSPACE_NAME}' is still not present after creation."
    echo "${_VERIFY}"
    exit 1
fi

echo "[INFO] Keyspaces now: $(echo "${_VERIFY}" | jq -r '.status.keyspaces | join(", ")')"

cat <<INFO

------------------------------------------------------------------
Keyspace '${KEYSPACE_NAME}' is ready on datacenter ${_PRIMARY_DC}.

It is already referenced by the values written to cpd_instance_details.sh:
  DATASTAX_HCD_KEYSPACE / DATASTAX_CQL_KEYSPACE = ${KEYSPACE_NAME}

Use it from the Data API, e.g. create a collection:
  curl -sS -k -X POST "${DATAAPI_ENDPOINT}/v1/${KEYSPACE_NAME}" \\
    -H "Token: \${DATASTAX_HCD_API_TOKEN}" \\
    -H "Content-Type: application/json" \\
    -d '{"createCollection":{"name":"my_collection"}}'
------------------------------------------------------------------
INFO
