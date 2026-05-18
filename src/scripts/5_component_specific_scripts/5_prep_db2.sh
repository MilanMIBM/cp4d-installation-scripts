#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---

for var in OC_LOGIN PREP_DB2; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

uidGidRange='1001000000/10000'

# -- apply necessary security ontext alterations
oc adm policy add-cluster-role-to-user system:controller:persistent-volume-binder system:serviceaccount:${PROJECT_CPD_INST_OPERANDS}:zen-databases-sa

oc annotate namespace ${PROJECT_CPD_INST_OPERANDS} --overwrite openshift.io/sa.scc.supplemental-groups=${uidGidRange} openshift.io/sa.scc.uid-range=${uidGidRange} openshift.io/sa.scc.mcs=s0:c27,c51

DB2_CONFIGMAP="oc apply -f - <<EOF
apiVersion: v1
data:
  DB2U_RUN_WITH_LIMITED_PRIVS: "false"
kind: ConfigMap
metadata:
  name: db2u-product-cm
  namespace: ${PROJECT_CPD_INST_OPERATORS}
EOF"

eval "${DB2_CONFIGMAP}"