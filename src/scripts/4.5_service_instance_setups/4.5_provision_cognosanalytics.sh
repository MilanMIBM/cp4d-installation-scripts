#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---

for var in OC_LOGIN CPDM_OC_LOGIN PREP_CA PREP_DB2; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

# ---
# export COGNOS_PAYLOAD_FILE="${SCRIPT_DIR}/cognos-analytics-instance.json"
export COGNOS_PAYLOAD_FILE="./cognos-analytics-instance.json"
CPD_PROFILE_NAME="${CPD_USERNAME}-profile"
# ---
CA_INSTANCE_VERSION="29.0.0"
CA_INSTANCE_NAME="cognosanalytics"
MYSQL_PV_SIZE=5 # recommended 20
COUCHDB_PV_SIZE=5 # recommended 20
MONGODB_PV_SIZE=5 # recommended 20
REDIS_PV_SIZE=5 # recommended 20
CA_INSTANCE_SIZE="small" # small_mincpureq, small, medium, large

FIPS_MODE=""
FIPS_MODE_LABEL=""
# ---
DB2_CONTENT_STORE_DEPLOYMENT_ID="${DB2_INSTANCE_NAME}"
DB2_CONTENT_STORE_PORT="c-${DB2_CONTENT_STORE_DEPLOYMENT_ID}-db2u.${PROJECT_CPD_INST_OPERANDS}.svc.cluster.local"
DB2_CONTENT_STORE_PORT=50000 # 50000 for non-ssl / 50001 for ssl


# ----------------------------
# WORK IN PROGRESS, NEED TO SET UP DB2 CONNECTION SETUPS
# ----------------------------

# # ---
# CONTENT_STORE_CONNECTION_NAME=""
# CONTENT_STORE_CONNECTION_PROPS=""
# # "persistence.class":"${STG_CLASS_BLOCK}" /or/ "${STG_CLASS_FILE}" and "tm1Service.storageClass":"${STG_CLASS_FILE}". 
# PREP_COGNOSANALYTICS='cat << EOF > ./cognos-analytics-instance.json
# {
#     "addon_type": "cognos-analytics-app",
#     "display_name": "${CA_INSTANCE_NAME}",
#     "namespace": "${PROJECT_CPD_INST_OPERANDS}",
#     "addon_version": "${CA_INSTANCE_VERSION}",
#     "create_arguments": {
#         "deployment_id": "",
#         "parameters": {
#             "fileStorageClass": "${STG_CLASS_FILE}",
#             "blockStorageClass": "${STG_CLASS_BLOCK}",
#             "fips": "${FIPS_MODE_LABEL}",
#             "planSize": "${CA_INSTANCE_SIZE}",
#             "audit": "${AUDIT_CONNECTION_NAME}",
#             "auditProperty": "${AUDIT_DB_CONNECTION_PROPS}",
#             "cs": "${CONTENT_STORE_CONNECTION_NAME}",
#             "csProperty": "${CONTENT_STORE_CONNECTION_PROPS}"
#         },
#         "resources": {},
#         "description": "",
#         "owner_username": "cpadmin"
#     },
#     "transient_fields": {}
# }
# EOF'

# eval "${PREP_COGNOSANALYTICS}"

# eval "${CPDM_OC_LOGIN}"

# cpd-cli service-instance create \
#     --profile=${CPD_PROFILE_NAME} \
#     --from-source=${COGNOS_PAYLOAD_FILE} \
#     # --preview