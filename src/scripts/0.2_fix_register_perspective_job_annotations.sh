#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/source_env_setup.sh"

# ---

for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "[ERROR] ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

NS="${PROJECT_CPD_INST_OPERANDS}"
JOB_NAME="register-perspective-job"

# ── 1. Check whether the job is stuck (exists with 0 active pods) ────────────

JOB_EXISTS=$(oc get job "${JOB_NAME}" -n "${NS}" --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [[ "${JOB_EXISTS}" -eq 0 ]]; then
    echo "[INFO] Job '${JOB_NAME}' not found in namespace '${NS}'. Nothing to fix."
    exit 0
fi

ACTIVE_PODS=$(oc get job "${JOB_NAME}" -n "${NS}" \
    -o jsonpath='{.status.active}' 2>/dev/null || echo "0")
SUCCEEDED=$(oc get job "${JOB_NAME}" -n "${NS}" \
    -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")

echo "[INFO] Job '${JOB_NAME}': active=${ACTIVE_PODS:-0}  succeeded=${SUCCEEDED:-0}"

if [[ "${SUCCEEDED:-0}" -ge 1 ]]; then
    echo "[INFO] Job already completed successfully. Nothing to fix."
    exit 0
fi

RUNNING_PODS=$(oc get pods -n "${NS}" \
    --selector="job-name=${JOB_NAME}" \
    --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [[ "${RUNNING_PODS}" -gt 0 ]]; then
    echo "[INFO] Job has ${RUNNING_PODS} pod(s) running. No annotation fix needed."
    exit 0
fi

echo "[INFO] Job is present but has no pods - checking for missing SCC annotations on namespace '${NS}'."

# ── 2. Check for the required annotations ────────────────────────────────────

UID_RANGE=$(oc get namespace "${NS}" \
    -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' 2>/dev/null || true)
SUP_GROUPS=$(oc get namespace "${NS}" \
    -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.supplemental-groups}' 2>/dev/null || true)

echo "[INFO] Current uid-range annotation  : '${UID_RANGE:-<missing>}'"
echo "[INFO] Current supplemental-groups   : '${SUP_GROUPS:-<missing>}'"

if [[ -n "${UID_RANGE}" && -n "${SUP_GROUPS}" ]]; then
    echo "[INFO] SCC annotations are present. The pod scheduling failure may have another cause."
    echo "[INFO] Check: oc describe job ${JOB_NAME} -n ${NS}"
    exit 0
fi

# ── 3. Derive a UID range from another namespace if possible ─────────────────
#      (falls back to a safe default if no reference namespace is found)

REFERENCE_RANGE=""
for ref_ns in "${PROJECT_CPD_INST_OPERATORS:-}" openshift-monitoring kube-system; do
    [[ -z "${ref_ns}" ]] && continue
    REFERENCE_RANGE=$(oc get namespace "${ref_ns}" \
        -o jsonpath='{.metadata.annotations.openshift\.io/sa\.scc\.uid-range}' 2>/dev/null || true)
    if [[ -n "${REFERENCE_RANGE}" ]]; then
        echo "[INFO] Borrowing UID range pattern from namespace '${ref_ns}': ${REFERENCE_RANGE}"
        break
    fi
done

if [[ -z "${REFERENCE_RANGE}" ]]; then
    REFERENCE_RANGE="1000700000/10000"
    echo "[WARN] No reference namespace found. Using default range: ${REFERENCE_RANGE}"
fi

# ── 4. Apply the missing annotations ─────────────────────────────────────────

echo "[INFO] Annotating namespace '${NS}'..."

[[ -z "${UID_RANGE}" ]] && \
    oc annotate namespace "${NS}" \
        "openshift.io/sa.scc.uid-range=${REFERENCE_RANGE}" \
        --overwrite && \
    echo "[OK]  Set openshift.io/sa.scc.uid-range=${REFERENCE_RANGE}"

[[ -z "${SUP_GROUPS}" ]] && \
    oc annotate namespace "${NS}" \
        "openshift.io/sa.scc.supplemental-groups=${REFERENCE_RANGE}" \
        --overwrite && \
    echo "[OK]  Set openshift.io/sa.scc.supplemental-groups=${REFERENCE_RANGE}"

# ── 5. Confirm and watch for pod creation ────────────────────────────────────

echo ""
echo "[INFO] Annotations after fix:"
oc get namespace "${NS}" -o jsonpath='{.metadata.annotations}' \
    | python3 -c "
import sys, json
ann = json.load(sys.stdin)
for k, v in ann.items():
    if 'scc' in k:
        print(f'  {k}: {v}')
"

echo ""
echo "[INFO] The job controller will retry pod creation shortly (exponential backoff)."
echo "[INFO] Watch pod creation with:"
echo "         oc get pods -n ${NS} -w | grep ${JOB_NAME}"
