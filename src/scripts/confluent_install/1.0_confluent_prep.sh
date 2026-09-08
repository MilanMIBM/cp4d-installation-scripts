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
# Confluent Platform - preparation
# ------------------------------------------------------------------------------
# Prepares the cluster for the cp-all-in-one stack installed by
# 1.1_confluent_install.sh:
#   - logs in to OpenShift
#   - validates the confluent_vars.sh configuration
#   - creates the target project
#   - creates the registry pull secret (if credentials are configured)
#   - grants the anyuid SCC to the service account (cp-* images run as a fixed uid)
#   - provisions the basic-auth credentials for the web UIs
#   - creates the broker's PersistentVolumeClaim
#
# Options:
#   --regenerate-password   discard the stored basic-auth password and mint a
#                           new one (components must be redeployed afterwards)
# ==============================================================================

REGENERATE_PASSWORD=false
while (( $# > 0 )); do
    case "$1" in
        --regenerate-password) REGENERATE_PASSWORD=true; shift ;;
        -h|--help)
            echo "Usage: $(basename $0) [--regenerate-password]"
            exit 0 ;;
        *) echo "[ERROR] Unknown argument '$1'. Use --help." >&2; exit 1 ;;
    esac
done

eval "${OC_LOGIN}"

NS="${PROJECT_CONFLUENT_SERVER}"
SA="confluent"

# ------------------------------------------------------------------------------
# Validate configuration
# ------------------------------------------------------------------------------
_missing=()
for _var in PROJECT_CONFLUENT_SERVER CONFLUENT_VERSION CONFLUENT_REGISTRY \
            CONFLUENT_CONNECT_IMAGE CONFLUENT_CLUSTER_ID CONFLUENT_STORAGE_CLASS \
            CONFLUENT_BROKER_STORAGE_SIZE CONFLUENT_REPLICATION_FACTOR \
            CONFLUENT_BROKER_REPLICAS; do
    [[ -z "${(P)_var:-}" ]] && _missing+=("${_var}")
done
if (( ${#_missing[@]} > 0 )); then
    echo "[ERROR] Missing required variables in cp4d_config/confluent_vars.sh: ${_missing[*]}" >&2
    exit 1
fi

if (( CONFLUENT_REPLICATION_FACTOR > CONFLUENT_BROKER_REPLICAS )); then
    echo "[ERROR] CONFLUENT_REPLICATION_FACTOR (${CONFLUENT_REPLICATION_FACTOR}) exceeds CONFLUENT_BROKER_REPLICAS (${CONFLUENT_BROKER_REPLICAS})." >&2
    exit 1
fi

# The KRaft cluster id must be a 16-byte UUID in url-safe base64 without
# padding (22 chars). Catch a malformed value here rather than in a
# CrashLoopBackOff when the broker fails to format its log dir.
if [[ ! "${CONFLUENT_CLUSTER_ID}" =~ ^[A-Za-z0-9_-]{22}$ ]]; then
    echo "[ERROR] CONFLUENT_CLUSTER_ID must be 22 characters of [A-Za-z0-9_-] (a base64url-encoded 16-byte UUID)." >&2
    echo "[ERROR] Got '${CONFLUENT_CLUSTER_ID}' (${#CONFLUENT_CLUSTER_ID} chars). Generate one with:" >&2
    echo "[ERROR]   python3 -c \"import base64,uuid;print(base64.urlsafe_b64encode(uuid.uuid4().bytes).decode().rstrip('='))\"" >&2
    exit 1
fi

if ! oc get storageclass "${CONFLUENT_STORAGE_CLASS}" &>/dev/null; then
    echo "[ERROR] StorageClass '${CONFLUENT_STORAGE_CLASS}' not found on the cluster." >&2
    echo "[ERROR] Available storage classes:" >&2
    oc get storageclass -o name >&2
    exit 1
fi

echo "[INFO] Configuration validated. Installing Confluent Platform ${CONFLUENT_VERSION} into project '${NS}'."

# ------------------------------------------------------------------------------
# Project
# ------------------------------------------------------------------------------
oc create namespace "${NS}" --dry-run=client -o yaml | oc apply -f -
oc project "${NS}" >/dev/null

# ------------------------------------------------------------------------------
# Service account + registry pull secret
# ------------------------------------------------------------------------------
oc create serviceaccount "${SA}" -n "${NS}" --dry-run=client -o yaml | oc apply -f -

if [[ -n "${CONFLUENT_REGISTRY_USER:-}" ]]; then
    _registry_host="${CONFLUENT_REGISTRY%%/*}"
    oc create secret docker-registry "${CONFLUENT_PULL_SECRET}" \
        --docker-server="${_registry_host}" \
        --docker-username="${CONFLUENT_REGISTRY_USER}" \
        --docker-password="${CONFLUENT_REGISTRY_PASSWORD}" \
        -n "${NS}" \
        --dry-run=client -o yaml | oc apply -f -
    oc secrets link "${SA}" "${CONFLUENT_PULL_SECRET}" --for=pull -n "${NS}"
    echo "[INFO] Registry pull secret '${CONFLUENT_PULL_SECRET}' created for ${_registry_host} and linked to serviceaccount/${SA}."
else
    echo "[INFO] CONFLUENT_REGISTRY_USER is empty - pulling anonymously from ${CONFLUENT_REGISTRY}."
fi

# ------------------------------------------------------------------------------
# SCC - the confluentinc/cp-* images run as a fixed non-root uid (appuser),
# which the default restricted-v2 SCC forbids.
# ------------------------------------------------------------------------------
oc adm policy add-scc-to-user anyuid -z "${SA}" -n "${NS}"
echo "[INFO] Granted anyuid SCC to serviceaccount/${SA} in ${NS}."

# ------------------------------------------------------------------------------
# Basic-auth credentials for the web UIs
# ------------------------------------------------------------------------------
# Upstream cp-all-in-one exposes Control Center, Prometheus and Alertmanager
# with no authentication whatsoever; its only secured variant is
# cp-all-in-one-security/oauth, which requires a Keycloak IdP. We use HTTP basic
# auth instead, which every one of those three components supports natively.
#
# The password is generated once and stored in the '${CONFLUENT_AUTH_SECRET}'
# secret, then reused on later runs so redeploys don't invalidate the
# credentials people already have.
if [[ "${CONFLUENT_AUTH_ENABLED}" == "true" ]]; then
    _auth_user="${CONFLUENT_AUTH_USERNAME}"
    if [[ -z "${_auth_user}" ]]; then
        echo "[ERROR] CONFLUENT_AUTH_USERNAME is empty (it defaults to \$OCP_USERNAME)." >&2
        exit 1
    fi

    # bcrypt is what Prometheus and Alertmanager require for basic_auth_users.
    # htpasswd ships with Apache tools and is the only dependency here; the
    # python bcrypt module is not installed in this repo's venv.
    if ! command -v htpasswd >/dev/null 2>&1; then
        echo "[ERROR] 'htpasswd' is required to hash the basic-auth password but was not found." >&2
        echo "[ERROR] Install it with: brew install httpd   (macOS)  |  dnf install httpd-tools  (RHEL)" >&2
        exit 1
    fi

    _existing_pw="$(oc get secret "${CONFLUENT_AUTH_SECRET}" -n "${NS}" \
        -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode 2>/dev/null || true)"

    if [[ -n "${CONFLUENT_AUTH_PASSWORD}" ]]; then
        _auth_pw="${CONFLUENT_AUTH_PASSWORD}"
        _pw_origin="taken from CONFLUENT_AUTH_PASSWORD"
    elif $REGENERATE_PASSWORD || [[ -z "${_existing_pw}" ]]; then
        # Alphanumeric plus a small punctuation set: strong, but safe to paste
        # into a URL, a shell, or a YAML file without quoting surprises.
        _auth_pw="$(LC_ALL=C tr -dc 'A-Za-z0-9._~-' < /dev/urandom \
            | head -c "${CONFLUENT_AUTH_PASSWORD_LENGTH}")"
        if $REGENERATE_PASSWORD && [[ -n "${_existing_pw}" ]]; then
            _pw_origin="regenerated (previous password discarded)"
            echo "[WARN] Regenerating the basic-auth password. Redeploy the components afterwards:"
            echo "[WARN]   oc rollout restart deployment -n ${NS} -l app.kubernetes.io/part-of=confluent"
        else
            _pw_origin="generated"
        fi
    else
        _auth_pw="${_existing_pw}"
        _pw_origin="reused from existing secret"
    fi

    if (( ${#_auth_pw} < 16 )); then
        echo "[WARN] Basic-auth password is only ${#_auth_pw} characters; 16 or more is recommended."
    fi

    # bcrypt hash for Prometheus/Alertmanager web-config basic_auth_users.
    _auth_bcrypt="$(htpasswd -bnBC 10 "${_auth_user}" "${_auth_pw}" 2>/dev/null | cut -d: -f2)"
    if [[ ! "${_auth_bcrypt}" =~ ^\$2[aby]\$ ]]; then
        echo "[ERROR] htpasswd did not produce a bcrypt hash (got: '${_auth_bcrypt}')." >&2
        exit 1
    fi

    oc create secret generic "${CONFLUENT_AUTH_SECRET}" \
        --from-literal=username="${_auth_user}" \
        --from-literal=password="${_auth_pw}" \
        --from-literal=bcrypt="${_auth_bcrypt}" \
        -n "${NS}" \
        --dry-run=client -o yaml | oc apply -f -

    echo "[INFO] Basic-auth credentials ready in secret '${CONFLUENT_AUTH_SECRET}' (${_pw_origin})."
    echo "[INFO]   username: ${_auth_user}"
    echo "[INFO]   password: read it with -"
    echo "[INFO]     oc get secret ${CONFLUENT_AUTH_SECRET} -n ${NS} -o jsonpath='{.data.password}' | base64 --decode"
else
    echo "[WARN] CONFLUENT_AUTH_ENABLED=false - the web UIs will be exposed without authentication."
fi

# ------------------------------------------------------------------------------
# Broker storage
# ------------------------------------------------------------------------------
# No PVC is created here: the broker StatefulSet declares a volumeClaimTemplate
# so each broker gets its own ${CONFLUENT_BROKER_STORAGE_SIZE} claim. Verify the
# storage class can bind that shape instead.
if [[ "$(oc get storageclass "${CONFLUENT_STORAGE_CLASS}" -o jsonpath='{.provisioner}' 2>/dev/null)" == "kubernetes.io/no-provisioner" ]]; then
    echo "[WARN] StorageClass '${CONFLUENT_STORAGE_CLASS}' has no dynamic provisioner;" \
         "${CONFLUENT_BROKER_REPLICAS} broker PVC(s) must be pre-provisioned manually." >&2
fi

echo "[INFO] Broker storage: ${CONFLUENT_BROKER_REPLICAS} x ${CONFLUENT_BROKER_STORAGE_SIZE} from '${CONFLUENT_STORAGE_CLASS}' (created by the StatefulSet)."
echo "[INFO] Preparation complete. Run 1.1_confluent_install.sh next."
