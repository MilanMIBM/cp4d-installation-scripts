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

for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS PROJECT_CPD_INST_OPERATORS PREP_DATASTAX; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

#---------------------------------------------------------------------------
##### DataStax CQL gateway (CqlConnectivity)
#####
##### Exposes a CassandraDatacenter for native CQL driver / cqlsh access from
##### OUTSIDE the cluster. This is the companion to the DataApi (HTTP/JSON)
##### created by 5_prep_datastax_mc.sh - same operator, different front door:
#####   DataApi          -> HTTP/JSON on 8080, plain OpenShift edge Route
#####   CqlConnectivity  -> native CQL binary protocol, TLS+SNI on 443
#####
##### The operator renders the Routes itself (TLS passthrough + SNI) from the
##### ingress.dnsBaseName below, so this script does NOT create Routes by hand.
##### Clients connect with a Secure Connect Bundle (SCB), which pins the host
##### and port for them - never with a bare host:9042 from outside.
#---------------------------------------------------------------------------

# Size of the cql-router pool fronting the datacenter. 1 is fine for a
# demo/TechZone footprint; raise for HA.
CQL_GATEWAY_SIZE="${CQL_GATEWAY_SIZE:-1}"

# SNI hostnames are children of this base name, which must resolve through the
# cluster's ingress wildcard, hence the *.apps domain.
_APPS_DOMAIN="$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')"
if [[ -z "${_APPS_DOMAIN}" ]]; then
    echo "Error: could not read the cluster ingress domain (ingresses.config/cluster)."
    exit 1
fi
CQL_GATEWAY_DNS_BASE="${CQL_GATEWAY_DNS_BASE:-cql.${_APPS_DOMAIN}}"
echo "[INFO] CQL gateway DNS base name: ${CQL_GATEWAY_DNS_BASE}"

# The cql-router pods run under the same 'datastax-mc' service account as the
# rest of Mission Control, so the SCC grant from 5_prep_datastax_mc.sh already
# covers them. Re-assert it so this script is safe to run standalone.
oc adm policy add-scc-to-user nonroot-v2 -z datastax-mc -n "${PROJECT_CPD_INST_OPERANDS}"

# Discover all CassandraDatacenter instance names in the operands namespace
DC_NAMES=($(oc get cassandradatacenters.cassandra.datastax.com -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.items[*].metadata.name}'))

if [[ ${#DC_NAMES[@]} -eq 0 ]]; then
    echo "Error: No CassandraDatacenter instances found in namespace ${PROJECT_CPD_INST_OPERANDS}."
    exit 1
fi

echo "Found CassandraDatacenter instances: ${DC_NAMES[*]}"

for DC_NAME in "${DC_NAMES[@]}"; do
    echo "--- Processing DC: ${DC_NAME} ---"

    # Reuse the annotations the operator already stamped on the datacenter so
    # the gateway inherits the same CP4D/backup bookkeeping as the DataApi.
    PREP_COMMON_DC_ANNOTATIONS="oc get cassandradatacenters.cassandra.datastax.com ${DC_NAME} -n ${PROJECT_CPD_INST_OPERANDS} -o json | jq '.spec.additionalAnnotations'"
    COMMON_ANNOTATIONS=$(eval "${PREP_COMMON_DC_ANNOTATIONS}")

    CQL_READY="$(oc get cqlconnectivity.missioncontrol.datastax.com "${DC_NAME}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    if [[ "${CQL_READY}" == "True" ]]; then
        echo "[INFO] CqlConnectivity '${DC_NAME}' already exists and is Ready - skipping creation."
    else
        PREP_DATASTAX_CQL="cat <<EOF | oc apply -f -
{
    \"apiVersion\": \"missioncontrol.datastax.com/v1alpha1\",
    \"kind\": \"CqlConnectivity\",
    \"metadata\": {
        \"name\": \"${DC_NAME}\",
        \"namespace\": \"${PROJECT_CPD_INST_OPERANDS}\"
    },
    \"spec\": {
        \"cassandraDatacenterRef\": {
            \"name\": \"${DC_NAME}\"
        },
        \"metadata\": {
            \"commonAnnotations\": ${COMMON_ANNOTATIONS},
            \"commonLabels\": {
                \"icpdsupport/addOnId\": \"datastax-mc\",
                \"velero.io/exclude-from-backup\": \"true\",
                \"icpdsupport/ignore-on-nd-backup\": \"true\",
                \"icpdsupport/empty-on-nd-backup\": \"true\"
            }
        },
        \"encryption\": {
            \"enabled\": true,
            \"caIssuer\": {
                \"enabled\": true
            }
        },
        \"ingress\": {
            \"dnsBaseName\": \"${CQL_GATEWAY_DNS_BASE}\",
            \"size\": ${CQL_GATEWAY_SIZE},
            \"podConfig\": {
                \"resources\": {
                    \"limits\": {
                        \"cpu\": 2,
                        \"memory\": \"2G\",
                        \"ephemeral-storage\": \"2Gi\"
                    },
                    \"requests\": {
                        \"cpu\": 1,
                        \"memory\": \"1G\",
                        \"ephemeral-storage\": \"1Gi\"
                    }
                }
            }
        }
    }
}
EOF"
        eval "${PREP_DATASTAX_CQL}"
    fi
done

# --- wait for the primary gateway to come up -------------------------------
_PRIMARY_DC="${DC_NAMES[1]}"

echo "[INFO] Waiting for CqlConnectivity '${_PRIMARY_DC}' to become Ready..."
for (( _attempt=1; _attempt<=30; _attempt++ )); do
    _READY="$(oc get cqlconnectivity.missioncontrol.datastax.com "${_PRIMARY_DC}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || true)"
    [[ "${_READY}" == "True" ]] && { echo "[INFO] CqlConnectivity '${_PRIMARY_DC}' is Ready."; break; }
    if (( _attempt == 30 )); then
        echo "[WARN] CqlConnectivity '${_PRIMARY_DC}' is not Ready after ~5 minutes; continuing so the rest of the values are still written." >&2
        oc get cqlconnectivity.missioncontrol.datastax.com "${_PRIMARY_DC}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}' 2>/dev/null || true
    fi
    sleep 10
done

oc get cqlconnectivity.missioncontrol.datastax.com -n "${PROJECT_CPD_INST_OPERANDS}"

# The operator renders one Route per gateway replica plus the SNI entrypoint.
echo "[INFO] Routes rendered by the CQL gateway:"
oc get routes -n "${PROJECT_CPD_INST_OPERANDS}" 2>/dev/null | grep -E "cql|${_PRIMARY_DC}" || echo "  (none yet)"

# --- write DataStax CQL gateway details to cpd_instance_details.sh ---------
REPO_ROOT="$(cd "${SCRIPT_DIR}" && while [[ ! -f pyproject.toml ]]; do cd ..; done && pwd)"
VARS_FILE="${REPO_ROOT}/cp4d_config/cpd_instance_details.sh"

# CQL auth uses the very same datacenter superuser as the DataApi.
_SUPERUSER_SECRET="datastax${_PRIMARY_DC//[^0-9]/}-superuser"
DATASTAX_CQL_USER="" DATASTAX_CQL_PASSWORD=""
for (( _attempt=1; _attempt<=5; _attempt++ )); do
    DATASTAX_CQL_USER="$(oc get secret "${_SUPERUSER_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode || true)"
    DATASTAX_CQL_PASSWORD="$(oc get secret "${_SUPERUSER_SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || true)"
    [[ -n "${DATASTAX_CQL_USER}" && -n "${DATASTAX_CQL_PASSWORD}" ]] && break
    _delay=$(( _attempt * 10 ))
    echo "[WARN] Secret '${_SUPERUSER_SECRET}' is missing username/password, retrying in ${_delay}s (attempt ${_attempt}/5)..." >&2
    sleep "${_delay}"
done
[[ -z "${DATASTAX_CQL_USER}" || -z "${DATASTAX_CQL_PASSWORD}" ]] && echo "[WARN] Secret '${_SUPERUSER_SECRET}' could not be fully retrieved after 5 retries." >&2

# In-cluster clients skip the gateway entirely and dial the headless service.
_CLUSTER_NAME="datastax${_PRIMARY_DC//[^0-9]/}"
DATASTAX_CQL_INCLUSTER_HOST="${_CLUSTER_NAME}-${_PRIMARY_DC}-service.${PROJECT_CPD_INST_OPERANDS}.svc.cluster.local"

# External clients go through the SNI gateway on 443.
DATASTAX_CQL_SNI_ENDPOINT="${_PRIMARY_DC}.${CQL_GATEWAY_DNS_BASE}"

DATASTAX_CQL_BLOCK="
# Written by $(basename $0) on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#--- DataStax HyperConvergedDatabase (HCD) - CQL gateway (CqlConnectivity)
export DATASTAX_CQL_DC=\"${_PRIMARY_DC}\"
export DATASTAX_CQL_LOCAL_DC=\"${_PRIMARY_DC}\"
export DATASTAX_CQL_CLUSTER=\"${_CLUSTER_NAME}\"
export DATASTAX_CQL_USER=\"${DATASTAX_CQL_USER}\"
export DATASTAX_CQL_PASSWORD=\"${DATASTAX_CQL_PASSWORD}\"
export DATASTAX_CQL_KEYSPACE=\"default_keyspace\"
# External access: TLS + SNI through the gateway on 443 (use the SCB, not host:port)
export DATASTAX_CQL_SNI_ENDPOINT=\"${DATASTAX_CQL_SNI_ENDPOINT}\"
export DATASTAX_CQL_SNI_PORT=\"443\"
export DATASTAX_CQL_DNS_BASE=\"${CQL_GATEWAY_DNS_BASE}\"
# In-cluster access: native CQL straight at the headless service
export DATASTAX_CQL_INCLUSTER_HOST=\"${DATASTAX_CQL_INCLUSTER_HOST}\"
export DATASTAX_CQL_INCLUSTER_PORT=\"9042\""

if [[ -f "${VARS_FILE}" ]]; then
    echo "${DATASTAX_CQL_BLOCK}" >> "${VARS_FILE}"
    echo "[INFO] DataStax CQL gateway details appended to ${VARS_FILE##*/}"
else
    mkdir -p "$(dirname "${VARS_FILE}")"
    echo "${DATASTAX_CQL_BLOCK}" > "${VARS_FILE}"
    echo "[INFO] DataStax CQL gateway details written to ${VARS_FILE##*/}"
fi

cat <<INFO

------------------------------------------------------------------
DataStax CQL gateway is configured.

In-cluster (no gateway, no SCB needed):
  cqlsh ${DATASTAX_CQL_INCLUSTER_HOST} 9042 -u <user> -p <password>

From your laptop, open a tunnel to the datacenter service:
  oc port-forward -n ${PROJECT_CPD_INST_OPERANDS} svc/${_CLUSTER_NAME}-${_PRIMARY_DC}-service 9042:9042
  cqlsh 127.0.0.1 9042 -u "\${DATASTAX_CQL_USER}" -p "\${DATASTAX_CQL_PASSWORD}"

Through the SNI gateway, download the Secure Connect Bundle from the
Mission Control UI (Databases > ${_PRIMARY_DC} > Connect), then:
  cqlsh -b /path/to/secure-connect-bundle.zip -u <user> -p <password>
The SCB pins host and port itself - do not pass a host or port with -b.
------------------------------------------------------------------
INFO
