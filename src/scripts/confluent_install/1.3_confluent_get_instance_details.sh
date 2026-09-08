#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# --- Config target: source confluent_vars.sh LAST so its cluster/storage values
# win over the CP4D ones defined in cpd_vars.sh. Override to point these
# scripts at a different config:  ENV_TARGET=<name|path> ./<script>.sh
: "${ENV_TARGET:=confluent}"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

# ==============================================================================
# Confluent Platform - collect instance details
# ------------------------------------------------------------------------------
# Discovers the live endpoints of the installed cp-all-in-one stack and writes
# them to cp4d_config/confluent_instance_details.sh, mirroring how
# 3.3.1_get_instance_creds.sh writes cpd_instance_details.sh.
#
# The generated file is picked up automatically on the next run of any script in
# this repo, because source_env_setup.sh sources every *.sh in cp4d_config/.
# ==============================================================================

eval "${OC_LOGIN}"

NS="${PROJECT_CONFLUENT_SERVER}"

if ! oc get namespace "${NS}" &>/dev/null; then
    echo "[ERROR] Project '${NS}' does not exist. Run the install scripts first." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# route_url <name> - external https URL for a route, empty if absent.
# ------------------------------------------------------------------------------
route_url() {
    local name="$1" host
    host="$(oc get route "${name}" -n "${NS}" -o jsonpath='{.spec.host}' 2>/dev/null || true)"
    [[ -n "${host}" ]] && echo "https://${host}"
}

# ------------------------------------------------------------------------------
# svc_url <name> <port> - in-cluster URL, only if the service exists.
# ------------------------------------------------------------------------------
svc_url() {
    local name="$1" port="$2"
    oc get service "${name}" -n "${NS}" &>/dev/null && echo "http://${name}.${NS}.svc.cluster.local:${port}"
}

echo "[INFO] Collecting Confluent endpoints from project '${NS}'..."

# In-cluster bootstrap: what applications running on the cluster should use.
CONFLUENT_BOOTSTRAP_INTERNAL="broker.${NS}.svc.cluster.local:${CONFLUENT_BROKER_INTERNAL_PORT}"

CONFLUENT_SCHEMA_REGISTRY_INTERNAL_URL="$(svc_url schema-registry "${CONFLUENT_SCHEMA_REGISTRY_PORT}")"
CONFLUENT_CONNECT_INTERNAL_URL="$(svc_url connect "${CONFLUENT_CONNECT_PORT}")"
CONFLUENT_KSQLDB_INTERNAL_URL="$(svc_url ksqldb-server "${CONFLUENT_KSQLDB_PORT}")"
CONFLUENT_REST_PROXY_INTERNAL_URL="$(svc_url rest-proxy "${CONFLUENT_REST_PROXY_PORT}")"
CONFLUENT_CONTROL_CENTER_INTERNAL_URL="$(svc_url control-center "${CONFLUENT_CONTROL_CENTER_PORT}")"

CONFLUENT_SCHEMA_REGISTRY_URL="$(route_url schema-registry)"
CONFLUENT_CONNECT_URL="$(route_url connect)"
CONFLUENT_KSQLDB_URL="$(route_url ksqldb-server)"
CONFLUENT_REST_PROXY_URL="$(route_url rest-proxy)"
CONFLUENT_CONTROL_CENTER_URL="$(route_url control-center)"

# Cluster id as the running broker reports it, falling back to the configured
# value when the broker is not up yet.
CONFLUENT_RUNNING_CLUSTER_ID="$(oc get statefulset broker -n "${NS}" \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="CLUSTER_ID")].value}' 2>/dev/null || true)"
CONFLUENT_RUNNING_CLUSTER_ID="${CONFLUENT_RUNNING_CLUSTER_ID:-${CONFLUENT_CLUSTER_ID}}"

# Resolve the deployed version from the broker image tag, so the file records
# what is actually running rather than what "latest" meant at install time.
_broker_image="$(oc get statefulset broker -n "${NS}" \
    -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
CONFLUENT_DEPLOYED_VERSION="${_broker_image##*:}"

# Basic-auth credentials for the web UIs, read back from the secret created by
# 1.0_confluent_prep.sh. Empty when authentication is disabled.
: "${CONFLUENT_AUTH_SECRET:=confluent-auth}"
CONFLUENT_AUTH_USER="$(oc get secret "${CONFLUENT_AUTH_SECRET}" -n "${NS}" -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode || true)"
CONFLUENT_AUTH_PASS="$(oc get secret "${CONFLUENT_AUTH_SECRET}" -n "${NS}" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || true)"

REPO_ROOT="$(cd "${SCRIPT_DIR}" && while [[ ! -f pyproject.toml ]]; do cd ..; done && pwd)"
VARS_FILE="${REPO_ROOT}/cp4d_config/confluent_instance_details.sh"

cat > "${VARS_FILE}" <<EOF
# Written by $(basename $0) on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Live endpoints of the Confluent Platform stack in project '${NS}'.
# Regenerate with: src/scripts/confluent_install/$(basename $0)

export CONFLUENT_NAMESPACE="${NS}"
export CONFLUENT_DEPLOYED_VERSION="${CONFLUENT_DEPLOYED_VERSION}"
export CONFLUENT_RUNNING_CLUSTER_ID="${CONFLUENT_RUNNING_CLUSTER_ID}"

# --- Web UI basic auth (Control Center, Prometheus, Alertmanager) -------------
# Empty when CONFLUENT_AUTH_ENABLED=false.
export CONFLUENT_AUTH_USER="${CONFLUENT_AUTH_USER}"
export CONFLUENT_AUTH_PASS="${CONFLUENT_AUTH_PASS}"

# --- In-cluster (use these from workloads running on the cluster) -------------
export CONFLUENT_BOOTSTRAP_INTERNAL="${CONFLUENT_BOOTSTRAP_INTERNAL}"
export CONFLUENT_SCHEMA_REGISTRY_INTERNAL_URL="${CONFLUENT_SCHEMA_REGISTRY_INTERNAL_URL}"
export CONFLUENT_CONNECT_INTERNAL_URL="${CONFLUENT_CONNECT_INTERNAL_URL}"
export CONFLUENT_KSQLDB_INTERNAL_URL="${CONFLUENT_KSQLDB_INTERNAL_URL}"
export CONFLUENT_REST_PROXY_INTERNAL_URL="${CONFLUENT_REST_PROXY_INTERNAL_URL}"
export CONFLUENT_CONTROL_CENTER_INTERNAL_URL="${CONFLUENT_CONTROL_CENTER_INTERNAL_URL}"

# --- External routes (empty when CONFLUENT_CREATE_ROUTES is false) ------------
export CONFLUENT_SCHEMA_REGISTRY_URL="${CONFLUENT_SCHEMA_REGISTRY_URL}"
export CONFLUENT_CONNECT_URL="${CONFLUENT_CONNECT_URL}"
export CONFLUENT_KSQLDB_URL="${CONFLUENT_KSQLDB_URL}"
export CONFLUENT_REST_PROXY_URL="${CONFLUENT_REST_PROXY_URL}"
export CONFLUENT_CONTROL_CENTER_URL="${CONFLUENT_CONTROL_CENTER_URL}"
EOF

echo ""
cat "${VARS_FILE}"
echo ""
echo "[INFO] Confluent instance details written to ${VARS_FILE##*/}"
