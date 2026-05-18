#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../source_env_setup.sh"

# ---

for var in OC_LOGIN CPDM_OC_LOGIN PREP_DB2; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "Error: ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"
DB2_USERNAME="db2admin"
DB2_PASSWORD="apass123!"
DB2_Version="12.1.3.0-cn3"
DB2_CPU_LIMIT="1" # 1vCPUs also can be defined as "1000m"
DB2_MEMORY_LIMIT="4Gi" # 4GB
DB2_STORAGE_CLAIM=20 # 20GB default, applied on all storage classes volume claims, adjust manually if necessary
DB2_4K_DEVICE_SUPPORT="ON" # ON / OFF

DB2_ID=$((RANDOM % 9000000 + 1000000)) # Random 7 digit id suffix

export DB2_INSTANCE_NAME="db2oltp-1${DB2_ID}"
CPD_PROFILE_NAME="${CPD_USERNAME}-profile"

PREP_DB2CONFIG="cat << EOF > ./db2oltp.yaml
apiVersion: db2u.databases.ibm.com/v1
kind: Db2uInstance
metadata:
  labels:
    cpd_db2: db2oltp
    db2u/cpdbr: db2u
    icpdsupport/addOnId: db2oltp
    icpdsupport/app: ${DB2_INSTANCE_NAME}
    icpdsupport/module: db2u
  annotations:
    openshift.io/required-scc: "restricted-v2"
  name: ${DB2_INSTANCE_NAME}
  namespace: ${PROJECT_CPD_INST_OPERANDS}
spec:
  account:
    imagePullSecrets:
    - ${IMAGE_PULL_SECRET}
    securityConfig:
      nonRootInstall: true
      privilegedSysctlInit: false
  addOns:
    graph:
      enabled: false
    opendataformats:
      workloadProfile: default
    qrep:
      enabled: false
      license: {}
    rest:
      enabled: true
  advOpts:
    db2SecurityPlugin: cloud_gss_plugin
    zenControlPlaneNamespace: ${PROJECT_CPD_INST_OPERANDS}
  affinity:
    nodeAffinity: {}
  environment:
    authentication:
      ldap:
        enabled: false
    databases:
    - name: BLUDB
      settings:
        dftPageSize: '16384'
      storage:
      - name: data
        spec:
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: ${DB2_STORAGE_CLAIM}
          storageClassName: ${STG_CLASS_BLOCK}
        type: template
      - name: activelogs
        spec:
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: ${DB2_STORAGE_CLAIM}
          storageClassName: ${STG_CLASS_BLOCK}
        type: template
      - name: tempts
        spec:
          accessModes:
          - ReadWriteOnce
          resources:
            requests:
              storage: ${DB2_STORAGE_CLAIM}
          storageClassName: ${STG_CLASS_FILE}
        type: template
    dbType: db2oltp
    instance:
      dbmConfig:
        SRVCON_PW_PLUGIN: IBMIAMauthpwfile
        group_plugin: IBMIAMauthgroup
        srvcon_auth: GSS_SERVER_ENCRYPT
        srvcon_gssplugin_list: IBMIAMauth
      password:
        value: ${DB2_PASSWORD}
      registry:
        DB2_4K_DEVICE_SUPPORT: ${DB2_4K_DEVICE_SUPPORT}
        DB2_FMP_RUN_AS_CONNECTED_USER: 'NO'
        DB2AUTH: OSAUTHDB,ALLOW_LOCAL_FALLBACK,PLUGIN_AUTO_RELOAD
    partitionConfig:
      total: 1
    ssl:
      allowSslOnly: false
      certLabel: CN=zen-ca-cert
      secretName: 'db2oltp-internal-tls'
  license:
    accept: true
  nodes: 1
  podTemplate:
    db2u:
      resource:
        db2u:
          limits:
            cpu: ${DB2_CPU_LIMIT}
            memory: ${DB2_MEMORY_LIMIT}
  storage:
  - name: meta
    spec:
      accessModes:
      - ReadWriteMany
      resources:
        requests:
          storage: ${DB2_STORAGE_CLAIM}
      storageClassName: ${STG_CLASS_FILE}
    type: create
  - name: backup
    spec:
      accessModes:
      - ReadWriteMany
      resources:
        requests:
          storage: ${DB2_STORAGE_CLAIM}
      storageClassName: ${STG_CLASS_FILE}
    type: create
  - name: archivelogs
    spec:
      accessModes:
      - ReadWriteMany
      resources:
        requests:
          storage: ${DB2_STORAGE_CLAIM}
      storageClassName: ${STG_CLASS_FILE}
    type: create
  version: ${DB2_Version}
  volumeSources:
  - visibility:
    - db2u
    volumeSource:
      secret:
        secretName: zen-service-broker-secret
  - visibility:
    - db2u
    volumeSource:
      configMap:
        name: management-ingress-ibmcloud-cluster-info"

eval "${PREP_DB2CONFIG}"

# --- Log into the cluster and create the resource.

eval "${OC_LOGIN}"

oc create -f ./db2oltp.yaml

# --- Observe the progress in provisioning of Db2

echo "Waiting for ${DB2_INSTANCE_NAME} to reach Ready state..."
oc wait db2uinstance "${DB2_INSTANCE_NAME}" --for=jsonpath='{.status.state}'=Ready --timeout=30m

cpd-cli service-instance status "${DB2_INSTANCE_NAME}" --profile="${CPD_PROFILE_NAME}" --service-type=db2oltp
