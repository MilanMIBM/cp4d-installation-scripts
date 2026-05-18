#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

for var in CPDM_OC_LOGIN PREP_MONGODB; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${CPDM_OC_LOGIN}"

# --- Shared Configurations
AUTO_DELETE_RESOURCES=true
CPD_PROFILE_NAME="${CPD_USERNAME}-profile"
SINGLE_MANAGER_SETUP=true # If true, skips Ops Manager creation when an instance with MONGO_MANAGER_INSTANCE_NAME already exists and only creates another database instance.


# --- Configuration - MongoDB Ops Manager
# export MONGO_MANAGER_PAYLOAD_FILE="${SCRIPT_DIR}/mongodb-opsmanager-instance.json"
export MONGO_MANAGER_PAYLOAD_FILE="./mongodb-opsmanager-instance.json"

export MONGO_MANAGER_INSTANCE_NAME="mongodb-manager"
export MONGO_MANAGER_VERSION="8.0.6" # "8.0.6" or "7.0.15"
MONGO_MANAGER_DESCRIPTION=""
MONGO_MANAGER_USERNAME="${CPD_USERNAME:-cpadmin}"
MONGO_MANAGER_PASSWORD="${CPD_PASSWORD:-'apass123!'}"
MONGO_MANAGER_ON_DEDICATED=false

# MongoDB Ops - Metadata Manager
MD_INSTANCE_REPLICAS=1 # between 1 and 50 replicas
MD_REPLICA_CPU=1 # between 1 and 16 CPUs
MD_REPLICA_MEMORY=2 # between 1 and 64 GB
MD_STORAGE_SIZE=10 # between 1 and 300 GB Storage
# MongoDB Ops - Instance Manager
MONGO_MANAGER_INSTANCE_REPLICAS=1 # between 1 and 50 replicas
MONGO_MANAGER_REPLICA_CPU=2 # between 1 and 16 CPUs
MONGO_MANAGER_REPLICA_MEMORY=4 # between 1 and 64 GB
MONGO_MANAGER_STORAGE_SIZE=20 # between 1 and 1000 GB Storage

PREP_MONGODB_MANAGER='cat << EOF > ./mongodb-ops-mgr.json
{
    "addon_type": "opsmanager",
    "display_name": "${MONGO_MANAGER_INSTANCE_NAME}",
    "namespace": "${PROJECT_CPD_INST_OPERANDS}",
    "addon_version": "${MONGO_MANAGER_VERSION}",
    "create_arguments": {
        "description": "${MONGO_MANAGER_DESCRIPTION}",
        "metadata":{
            "opsusername":"${MONGO_MANAGER_USERNAME}",
            "opspassword":"${MONGO_MANAGER_PASSWORD}"
        },
    "parameters": {
        "mgrapplyondedicated": "${MONGO_MANAGER_ON_DEDICATED}",
        "mgrforcedeleteresources": "${AUTO_DELETE_RESOURCES}",
        "mdnumberofnodes": "${MD_INSTANCE_REPLICAS}",
        "mdcorespernode": "${MD_REPLICA_CPU}",
        "mdmemorypernode": "${MD_REPLICA_MEMORY}",
        "mdsize": "${MD_STORAGE_SIZE}",
        "mdunit": "Gi",
        "mdstorageclass": "${STG_CLASS_FILE}",
        "mgrnumberofnodes": "${MONGO_MANAGER_INSTANCE_REPLICAS}",
        "mgrcorespernode": "${MONGO_MANAGER_REPLICA_CPU}",
        "mgrmemorypernode": "${MONGO_MANAGER_REPLICA_MEMORY}",
        "mgrsize": "${MONGO_MANAGER_STORAGE_SIZE}",
        "mgrunit": "Gi",
        "mgrstorageclass": "${STG_CLASS_FILE}"
        "mgrversion": "${MONGO_MANAGER_VERSION}",
        }
    }
}
EOF'

eval "${PREP_MONGODB_MANAGER}"

# - Create Mongodb Manager instance
if [[ "${SINGLE_MANAGER_SETUP}" == true ]]; then
    EXISTING_MANAGER_STATUS=$(cpd-cli service-instance status ${MONGO_MANAGER_INSTANCE_NAME} \
        --profile=${CPD_PROFILE_NAME} \
        --output=json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ServiceInstanceStatusCode',''))" 2>/dev/null || echo "")

    if [[ "${EXISTING_MANAGER_STATUS}" == "PROVISIONED" || "${EXISTING_MANAGER_STATUS}" == "PROVISION_IN_PROGRESS" ]]; then
        echo "[INFO] MongoDB Ops Manager instance '${MONGO_MANAGER_INSTANCE_NAME}' already exists (status: ${EXISTING_MANAGER_STATUS}). Skipping manager creation."
    elif [[ "${EXISTING_MANAGER_STATUS}" == "FAILED" ]]; then
        echo "[ERROR] MongoDB Ops Manager instance '${MONGO_MANAGER_INSTANCE_NAME}' is in FAILED state. Review logs for zen-core-api and zen-watcher pods."
        exit 1
    else
        cpd-cli service-instance create \
            --profile=${CPD_PROFILE_NAME} \
            --from-source=${MONGO_MANAGER_PAYLOAD_FILE}
    fi
else
    cpd-cli service-instance create \
        --profile=${CPD_PROFILE_NAME} \
        --from-source=${MONGO_MANAGER_PAYLOAD_FILE}
fi

### --------------------------------------------------------------------


# --- Configuration - MongoDB Instance (Database Cluster itself)
# export MONGODB_PAYLOAD_FILE="${SCRIPT_DIR}/mongodb-cp4d-instance.json"
export MONGODB_PAYLOAD_FILE="./mongodb-cp4d-instance.json"

MONGODB_INSTANCE_NAME="mongodb-instance"
MONGODB_INSTANCE_VERSION="8.0.6-ent" # "8.0.6-ent" or "7.0.18-ent"
MONGODB_INSTANCE_DESCRIPTION=""
# MongoDB 
MONGO_INSTANCE_REPLICAS=2 # between 1 and 50 replicas
MONGO_INSTANCE_REPLICA_CPU=4 # between 1 and 16 CPUs
MONGO_INSTANCE_REPLICA_MEMORY=8 # between 1 and 64 GB
MONGO_INSTANCE_STORAGE_SIZE=50 # between 1 and 1000 GB Storage


PREP_MONGODB_INSTANCE='cat << EOF > ./mongodb-cp4d-instance.json
{
    "addon_type": "mongodb",
    "display_name": "${MONGODB_INSTANCE_NAME}",
    "namespace": "${PROJECT_CPD_INST_OPERANDS}",
    "addon_version": "${MONGODB_INSTANCE_VERSION}",
    "create_arguments": {
        "description": "${MONGODB_INSTANCE_DESCRIPTION}",
        "parameters": {
            "opsmanager": "${MONGO_MANAGER_INSTANCE_NAME}",
            "opsmgrversion": "${MONGO_MANAGER_VERSION}",
            "mgrforcedeleteresources": "${AUTO_DELETE_RESOURCES}",
            "mdbversion": "${MONGODB_INSTANCE_VERSION}",
            "numberofnodes": "${MONGO_INSTANCE_REPLICAS}",
            "corespernode": "${MONGO_INSTANCE_REPLICA_CPU}",
            "memorypernode": "${MONGO_INSTANCE_REPLICA_MEMORY}",
            "sstorageclass": "${STG_CLASS_FILE}",
            "ssize": "${MONGO_INSTANCE_STORAGE_SIZE}",
            "sunit": "Gi"
        }
    }
}
EOF'

eval "${PREP_MONGODB_INSTANCE}"

# - Create MongoDB cluster instance
cpd-cli service-instance create \
    --profile=${CPD_PROFILE_NAME} \
    --from-source=${MONGODB_PAYLOAD_FILE}