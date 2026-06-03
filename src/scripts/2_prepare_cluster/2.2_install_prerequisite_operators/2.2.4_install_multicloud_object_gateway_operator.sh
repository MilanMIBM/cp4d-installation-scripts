#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# (legacy hardcoded sourcing - replaced by universal crawl below)
# source "${SCRIPT_DIR}/../../source_env_setup.sh"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

[[ "${PREP_WXO:-}" == "true" ]] || { echo "[INFO] PREP_WXO is not set to true - skipping Multicloud Object Gateway setup."; exit 0; }

eval "${OC_LOGIN}"

# ------------------------------------------------------------------------------
# Step 1: Install standalone Multicloud Object Gateway (skip if ODF/Fusion DDF)
# ------------------------------------------------------------------------------
# ODF and IBM Fusion Data Foundation ship MCG already; only install for other storage.
MCG_ALREADY_INSTALLED=false
if oc get noobaa noobaa -n openshift-storage &>/dev/null; then
    echo "[INFO] NooBaa/MCG already installed in openshift-storage, skipping operator install."
    MCG_ALREADY_INSTALLED=true
fi

if [[ "${MCG_ALREADY_INSTALLED}" == "false" ]]; then
    echo "[INFO] Installing standalone Multicloud Object Gateway operator..."
    eval "${CPDM_OC_LOGIN}"

    cpd-cli manage deploy-noobaa-backing-store \
        --release="${VERSION}" \
        --cluster_resources=true

    echo "[INFO] Waiting for NooBaa to become Ready..."
    TIMEOUT=600
    ELAPSED=0
    INTERVAL=15
    while true; do
        NOOBAA_PHASE=$(oc get noobaa noobaa -n openshift-storage -o jsonpath='{.status.phase}' 2>/dev/null || true)
        if [[ "${NOOBAA_PHASE}" == "Ready" ]]; then
            echo "[INFO] NooBaa is Ready."
            break
        fi
        if (( ELAPSED >= TIMEOUT )); then
            echo "[ERROR] Timed out waiting for NooBaa to become Ready (phase: ${NOOBAA_PHASE:-unknown})." >&2
            exit 1
        fi
        echo "[INFO] Waiting for NooBaa (phase: ${NOOBAA_PHASE:-unknown})... ${ELAPSED}s elapsed"
        sleep "${INTERVAL}"
        (( ELAPSED += INTERVAL ))
    done
fi

eval "${OC_LOGIN}"

# ------------------------------------------------------------------------------
# Step 2: Discover NooBaa secrets
# ------------------------------------------------------------------------------
NOOBAA_ACCOUNT_CREDENTIALS_SECRET=$(
    oc get secrets -n openshift-storage --no-headers -o custom-columns=NAME:.metadata.name \
    | grep -E "^noobaa-admin" | head -1
)
NOOBAA_ACCOUNT_CERTIFICATE_SECRET=$(
    oc get secrets -n openshift-storage --no-headers -o custom-columns=NAME:.metadata.name \
    | grep -E "^noobaa-s3-serving-cert" | head -1
)

if [[ -z "${NOOBAA_ACCOUNT_CREDENTIALS_SECRET}" ]]; then
    echo "[ERROR] Could not find noobaa-admin secret in openshift-storage." >&2
    exit 1
fi
if [[ -z "${NOOBAA_ACCOUNT_CERTIFICATE_SECRET}" ]]; then
    echo "[ERROR] Could not find noobaa-s3-serving-cert secret in openshift-storage." >&2
    exit 1
fi

echo "[INFO] Using credentials secret: ${NOOBAA_ACCOUNT_CREDENTIALS_SECRET}"
echo "[INFO] Using certificate secret:  ${NOOBAA_ACCOUNT_CERTIFICATE_SECRET}"

# ------------------------------------------------------------------------------
# Step 3: Create MCG secrets for watsonx Orchestrate (includes watson_assistant)
# ------------------------------------------------------------------------------
eval "${CPDM_OC_LOGIN}"

echo "[INFO] Running setup-mcg for watson_assistant (required by watsonx Orchestrate)..."
cpd-cli manage setup-mcg \
    --components=watson_assistant \
    --cpd_instance_ns="${PROJECT_CPD_INST_OPERANDS}" \
    --noobaa_account_secret="${NOOBAA_ACCOUNT_CREDENTIALS_SECRET}" \
    --noobaa_cert_secret="${NOOBAA_ACCOUNT_CERTIFICATE_SECRET}"

eval "${OC_LOGIN}"

echo "[INFO] Verifying watson_assistant MCG secrets..."
for SECRET in noobaa-account-watson-assistant noobaa-cert-watson-assistant noobaa-uri-watson-assistant; do
    if ! oc get secret "${SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" &>/dev/null; then
        echo "[ERROR] Expected secret not found: ${SECRET} in ${PROJECT_CPD_INST_OPERANDS}" >&2
        exit 1
    fi
    echo "[INFO] Found: ${SECRET}"
done

eval "${CPDM_OC_LOGIN}"

echo "[INFO] Running setup-mcg for watsonx_orchestrate..."
cpd-cli manage setup-mcg \
    --components=watsonx_orchestrate \
    --cpd_instance_ns="${PROJECT_CPD_INST_OPERANDS}" \
    --noobaa_account_secret="${NOOBAA_ACCOUNT_CREDENTIALS_SECRET}" \
    --noobaa_cert_secret="${NOOBAA_ACCOUNT_CERTIFICATE_SECRET}"

eval "${OC_LOGIN}"

echo "[INFO] Verifying watsonx_orchestrate MCG secrets..."
for SECRET in noobaa-account-watsonx-orchestrate noobaa-cert-watsonx-orchestrate noobaa-uri-watsonx-orchestrate; do
    if ! oc get secret "${SECRET}" -n "${PROJECT_CPD_INST_OPERANDS}" &>/dev/null; then
        echo "[ERROR] Expected secret not found: ${SECRET} in ${PROJECT_CPD_INST_OPERANDS}" >&2
        exit 1
    fi
    echo "[INFO] Found: ${SECRET}"
done

echo "[INFO] Multicloud Object Gateway setup complete."
