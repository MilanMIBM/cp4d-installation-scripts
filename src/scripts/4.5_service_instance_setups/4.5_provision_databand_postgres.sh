#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

# =============================================================================
# PostgreSQL for Databand (data observability in watsonx.dataintegration)
# -----------------------------------------------------------------------------
# With enableDataObservability: true, the DatabandInstaller CR installs the
# databand chart with:
#     databand.sqlAlchemyConn.existingSecret.name: databand-postgres
# Neither the operator nor the chart creates that secret or a database - it is
# customer provided. Without it the databand-dbnd-web-migration-1 hook pod
# sits in Init with "secret databand-postgres not found", and the helm release
# stays pending-install.
#
# The chart reads these keys from the secret (configmap-env.yaml and
# job-dbnd-web-migration.yaml in databand-54.0.5) and appends /<dbname>:
#     connection.postgres.authentication.username
#     connection.postgres.authentication.password
#     connection.postgres.hosts.0.hostname
#     connection.postgres.hosts.0.port
# The values are interpolated into a SQLAlchemy URL WITHOUT url-encoding, so
# the password is kept alphanumeric.
#
# This script provisions a dedicated EDB Cluster via the CPD Postgres operator
# (already running in the operands namespace) and writes that secret.
# Run it before installing watsonx.dataintegration, or any time after - a
# stuck migration pod picks the secret up on its own once it exists.
# =============================================================================

for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

# --- Configuration
DBND_NAMESPACE="${PROJECT_CPD_INST_OPERANDS}"
DBND_SECRET_NAME="databand-postgres"            # must match sqlAlchemyConn.existingSecret.name
DBND_DB_NAME="databand"                         # must match sqlAlchemyConn.dbname
DBND_DB_USER="databand"
DBND_CLUSTER_NAME="${DBND_CLUSTER_NAME:-databand-postgres-edb}"
DBND_CREDS_SECRET_NAME="${DBND_CLUSTER_NAME}-app-credentials"
DBND_INSTANCES="${DBND_INSTANCES:-2}"           # 1 = no HA, 2+ = primary + replicas
DBND_STORAGE_SIZE="${DBND_STORAGE_SIZE:-20Gi}"
DBND_STORAGE_CLASS="${STG_CLASS_BLOCK:-ocs-storagecluster-ceph-rbd}"
DBND_PULL_SECRET="${IMAGE_PULL_SECRET:-pull-secret}"
# Postgres major version to reuse from the other CPD-managed EDB clusters.
# Leave DBND_PG_IMAGE unset to auto-resolve; the operator default is used if
# no cluster in the namespace runs this major version.
DBND_PG_MAJOR="${DBND_PG_MAJOR:-16}"
DBND_PG_IMAGE="${DBND_PG_IMAGE:-}"
DBND_WAIT_TIMEOUT="${DBND_WAIT_TIMEOUT:-15m}"
EDB_CLUSTER_RESOURCE="clusters.postgresql.k8s.enterprisedb.io"

# ---
eval "${OC_LOGIN}"

# --- The CPD Postgres (EDB) operator must be installed ---
if ! oc get crd "${EDB_CLUSTER_RESOURCE}" >/dev/null 2>&1; then
    echo "[ERROR] CRD ${EDB_CLUSTER_RESOURCE} not found - install Software Hub (cpd_platform) first."
    exit 1
fi

# --- Skip if the secret is already in place ---
if oc get secret "${DBND_SECRET_NAME}" -n "${DBND_NAMESPACE}" >/dev/null 2>&1; then
    echo "[INFO] Secret ${DBND_SECRET_NAME} already exists in ${DBND_NAMESPACE} - nothing to do."
    exit 0
fi

# --- Resolve the Postgres image ---
if [[ -z "${DBND_PG_IMAGE}" ]]; then
    DBND_PG_IMAGE="$(oc get "${EDB_CLUSTER_RESOURCE}" -n "${DBND_NAMESPACE}" \
        -o jsonpath='{range .items[*]}{.spec.imageName}{"\n"}{end}' \
        | grep -m1 "/postgresql:${DBND_PG_MAJOR}\." || true)"
fi
if [[ -n "${DBND_PG_IMAGE}" ]]; then
    echo "[INFO] Using Postgres image: ${DBND_PG_IMAGE}"
    IMAGE_LINE="  imageName: ${DBND_PG_IMAGE}"
else
    echo "[INFO] No Postgres ${DBND_PG_MAJOR} image found in ${DBND_NAMESPACE} - using the operator default image."
    IMAGE_LINE=""
fi

# --- App user credentials (reuse on re-run so the cluster and secret stay in sync) ---
if oc get secret "${DBND_CREDS_SECRET_NAME}" -n "${DBND_NAMESPACE}" >/dev/null 2>&1; then
    echo "[INFO] Reusing credentials from secret ${DBND_CREDS_SECRET_NAME}"
    DBND_DB_PASSWORD="$(oc get secret "${DBND_CREDS_SECRET_NAME}" -n "${DBND_NAMESPACE}" -o jsonpath='{.data.password}' | base64 -d)"
else
    DBND_DB_PASSWORD="$(openssl rand -hex 16)"
    oc create secret generic "${DBND_CREDS_SECRET_NAME}" -n "${DBND_NAMESPACE}" \
        --type=kubernetes.io/basic-auth \
        --from-literal=username="${DBND_DB_USER}" \
        --from-literal=password="${DBND_DB_PASSWORD}"
fi

# --- EDB Cluster ---
echo "[INFO] Applying EDB Cluster ${DBND_CLUSTER_NAME} in ${DBND_NAMESPACE}"
cat <<EOF | oc apply -f -
apiVersion: postgresql.k8s.enterprisedb.io/v1
kind: Cluster
metadata:
  name: ${DBND_CLUSTER_NAME}
  namespace: ${DBND_NAMESPACE}
spec:
  description: PostgreSQL cluster for Databand (data observability)
  instances: ${DBND_INSTANCES}
${IMAGE_LINE}
  imagePullSecrets:
  - name: ${DBND_PULL_SECRET}
  enableSuperuserAccess: false
  bootstrap:
    initdb:
      database: ${DBND_DB_NAME}
      owner: ${DBND_DB_USER}
      encoding: UTF8
      secret:
        name: ${DBND_CREDS_SECRET_NAME}
  postgresql:
    parameters:
      max_connections: "300"
      shared_buffers: 512MB
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: "2"
      memory: 2Gi
  storage:
    size: ${DBND_STORAGE_SIZE}
    storageClass: ${DBND_STORAGE_CLASS}
EOF

# --- Connection secret in the format the databand chart expects ---
oc create secret generic "${DBND_SECRET_NAME}" -n "${DBND_NAMESPACE}" \
    --from-literal=connection.postgres.authentication.username="${DBND_DB_USER}" \
    --from-literal=connection.postgres.authentication.password="${DBND_DB_PASSWORD}" \
    --from-literal=connection.postgres.hosts.0.hostname="${DBND_CLUSTER_NAME}-rw.${DBND_NAMESPACE}.svc" \
    --from-literal=connection.postgres.hosts.0.port=5432
echo "[INFO] Created secret ${DBND_SECRET_NAME}"

# --- Wait for the database ---
echo "[INFO] Waiting up to ${DBND_WAIT_TIMEOUT} for ${DBND_CLUSTER_NAME} to become Ready..."
oc wait "${EDB_CLUSTER_RESOURCE}/${DBND_CLUSTER_NAME}" -n "${DBND_NAMESPACE}" \
    --for=condition=Ready --timeout="${DBND_WAIT_TIMEOUT}"
oc get "${EDB_CLUSTER_RESOURCE}" "${DBND_CLUSTER_NAME}" -n "${DBND_NAMESPACE}"

# --- A migration pod that already gave up waiting will not retry on its own ---
if oc get pods -n "${DBND_NAMESPACE}" -l job-name=databand-dbnd-web-migration-1 --no-headers 2>/dev/null | grep -q -E 'Error|Init:Error|Failed'; then
    echo "[WARN] databand-dbnd-web-migration-1 has a failed pod. If the job does not retry, delete it:"
    echo "       oc delete pod -n ${DBND_NAMESPACE} -l job-name=databand-dbnd-web-migration-1"
fi
