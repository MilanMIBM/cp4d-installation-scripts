#===============================================================================
# IBM Software Hub installation variables
#===============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
[ -f "${SCRIPT_DIR}/.env" ] && source "${SCRIPT_DIR}/.env"

# ------------------------------------------------------------------------------
# Client workstation 
# ------------------------------------------------------------------------------
# Set the following variables if you want to override the default behavior of the IBM Software Hub CLI.
#
# To export these variables, you must uncomment each command in this section.

# export CPD_CLI_MANAGE_WORKSPACE=<enter a fully qualified directory>
# export OLM_UTILS_LAUNCH_ARGS=<enter launch arguments>

# ------------------------------------------------------------------------------
# Cluster
# ------------------------------------------------------------------------------

export OCP_URL="https://api.itz..."
export OPENSHIFT_TYPE="self-managed"
export IMAGE_ARCH="amd64"

export OCP_USERNAME="kubeadmin"
export OCP_PASSWORD="<password>"
export LOGIN_ARGUMENTS="--username=${OCP_USERNAME} --password=${OCP_PASSWORD}"

export SERVER_ARGUMENTS="--server=${OCP_URL}"
export OC_LOGIN="oc login ${SERVER_ARGUMENTS} ${LOGIN_ARGUMENTS}"
export CPDM_OC_LOGIN="cpd-cli manage login-to-ocp ${SERVER_ARGUMENTS} ${LOGIN_ARGUMENTS}"

# ------------------------------------------------------------------------------
# Projects
# ------------------------------------------------------------------------------

export PROJECT_LICENSE_SERVICE="ibm-licensing"
export PROJECT_SCHEDULING_SERVICE="ibm-scheduler"
export PROJECT_IBM_EVENTS="ibm-knative-events"
export PROJECT_PRIVILEGED_MONITORING_SERVICE="ibm-cpd-privileged"
export PROJECT_CPD_INST_OPERATORS="cpd-operators"
export PROJECT_CPD_INST_OPERANDS="cpd-operands"

# ------------------------------------------------------------------------------
# Storage
# ------------------------------------------------------------------------------

export STG_CLASS_BLOCK="ocs-storagecluster-ceph-rbd"
export STG_CLASS_FILE="ocs-storagecluster-cephfs"

# ------------------------------------------------------------------------------
# IBM Entitled Registry Key
# ------------------------------------------------------------------------------

export IBM_ENTITLEMENT_KEY="<ibm entitlement key>"

# ------------------------------------------------------------------------------
# Image pull configuration
# ------------------------------------------------------------------------------

export IMAGE_PULL_SECRET="ibm-image-pull-secret"
export IMAGE_PULL_CREDENTIALS="$(echo -n "cp:$IBM_ENTITLEMENT_KEY" | base64 -w 0)"
export IMAGE_PULL_PREFIX="icr.io"

# ------------------------------------------------------------------------------
# IBM Software Hub version
# ------------------------------------------------------------------------------

export VERSION="5.3.1"
export PATCH_ID="latest"
export OLM_UTILS_IMAGE="icr.io/cpopen/cpd/olm-utils-v4:${VERSION}"
export CPD_ADMIN_USERNAME="kubeadmin"

# ------------------------------------------------------------------------------
# Components
# ------------------------------------------------------------------------------

export SOFTWARE_HUB="ibm-licensing,scheduler,cpfs,cpd_platform"
export COMPONENTS="analyticsengine,db2oltp,db2wh,dv,informix_cp4d,mongodb_cp4d,planning_analytics,productmaster,watsonx_ai,watsonx_data,watsonx_governance,ws_pipelines,datastax_mc"
export CPD_COMPONENTS="${SOFTWARE_HUB},${COMPONENTS}"
export UPDATE="false"
export INSTALL_OPTIONS="true"
export INSTALL_OPTIONS_FILE="install-options.yml"

# ------------------------------------------------------------------------------
# License Entitlements
# ------------------------------------------------------------------------------

export PROD_LICENSE="true"
export LICENSE_ENTITLEMENTS="cpd-enterprise,cognos-analytics,planning-analytics,product-master,watsonx-ai,watsonx-data,watsonx-data-premium,watsonx-dataintegration,watsonx-dataintelligence,watsonx-gov-mm,watsonx-gov-rc"

# ------------------------------------------------------------------------------
# Product Specific SCC requirements
# ------------------------------------------------------------------------------

export PREP_DB2="true"
export PREP_OPENSEARCH="true"
export PREP_INFORMIX="true"
export PREP_DATASTAX="true"
export PREP_PA="true"
