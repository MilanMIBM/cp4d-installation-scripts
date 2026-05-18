#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---

for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS PREP_DATASTAX; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

# --- prepares prepares nonroot-v2 security context to the service
oc adm policy add-scc-to-user nonroot-v2 -z datastax-mc -n ${PROJECT_CPD_INST_OPERANDS}
# --- extracts DataStax Mission Control login credentials
oc extract secret/datastax-mc-embedded-ui-dex-admin-credentials -n ${PROJECT_CPD_INST_OPERATORS} --to=-

# --- prepares route to the service so that it can be accessed

PREP_DATASTAX_ROUTE="cat <<EOF | oc apply --namespace ${PROJECT_CPD_INST_OPERATORS} -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: datastax-mc-ui
spec:
  tls:
    termination: passthrough
  to:
    kind: Service
    name: datastax-mc-ui
    weight: 100
EOF"
eval "${PREP_DATASTAX_ROUTE}"

# eval "${PREP_DATASTAX_ANNOTATION}" VVV same as below

oc label ns ${PROJECT_CPD_INST_OPERATORS}  mission-control.datastax.com/is-project=true
oc annotate ns ${PROJECT_CPD_INST_OPERATORS}  mission-control.datastax.com/project-name=${PROJECT_CPD_INST_OPERATORS}
oc label ns ${PROJECT_CPD_INST_OPERANDS}  mission-control.datastax.com/is-project=true
oc annotate ns ${PROJECT_CPD_INST_OPERANDS}  mission-control.datastax.com/project-name=${PROJECT_CPD_INST_OPERANDS}

# Discover all CassandraDatacenter instance names in the operands namespace
DC_NAMES=($(oc get cassandradatacenters.cassandra.datastax.com -n "${PROJECT_CPD_INST_OPERANDS}" -o jsonpath='{.items[*].metadata.name}'))

if [[ ${#DC_NAMES[@]} -eq 0 ]]; then
    echo "Error: No CassandraDatacenter instances found in namespace ${PROJECT_CPD_INST_OPERANDS}."
    exit 1
fi

echo "Found CassandraDatacenter instances: ${DC_NAMES[*]}"

for DC_NAME in "${DC_NAMES[@]}"; do
    echo "--- Processing DC: ${DC_NAME} ---"

    PREP_COMMON_DC_ANNOTATIONS="oc get cassandradatacenters.cassandra.datastax.com ${DC_NAME} -n ${PROJECT_CPD_INST_OPERANDS} -o json | jq '.spec.additionalAnnotations'"
    COMMON_ANNOTATIONS=$(eval "${PREP_COMMON_DC_ANNOTATIONS}")
    echo ${COMMON_ANNOTATIONS}

    PREP_DATASTAX_API="cat <<EOF | oc apply -f -
{
    \"apiVersion\": \"missioncontrol.datastax.com/v1alpha1\",
    \"kind\": \"DataApi\",
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
        \"replicas\": 1,
        \"resources\": {
            \"limits\": {
                \"cpu\": 1,
                \"memory\": \"1G\",
                \"ephemeral-storage\": \"500Mi\"
            },
            \"requests\": {
                \"cpu\": 1,
                \"memory\": \"1G\",
                \"ephemeral-storage\": \"500Mi\"
            }
        },
        \"services\": {
            \"clusterIP\": {
                \"port\": 8080
            }
        }
    }
}
EOF"
    eval "${PREP_DATASTAX_API}"
    DCNAME_SUPERUSER=$(eval "oc extract secret/datastax${DC_NAME//[^0-9]/}-superuser -n ${PROJECT_CPD_INST_OPERANDS}  --to=-")
    echo ${DCNAME_SUPERUSER}
done


oc get cassandradatacenters.cassandra.datastax.com -n "${PROJECT_CPD_INST_OPERANDS}"