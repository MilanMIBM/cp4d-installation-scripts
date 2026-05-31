#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/../scripts/source_env_setup.sh"

# ---

# Target buffer sizes. Override from environment if needed:
#   NGINX_LARGE_CLIENT_HEADER_BUFFERS="8 128k" ./patch_nginx_buffer_sizes.sh
LARGE_CLIENT_HEADER_BUFFERS="${NGINX_LARGE_CLIENT_HEADER_BUFFERS:-8 64k}"
CLIENT_HEADER_BUFFER_SIZE="${NGINX_CLIENT_HEADER_BUFFER_SIZE:-32k}"

for var in OC_LOGIN PROJECT_CPD_INST_OPERANDS; do
    if [[ -z "${(P)var:-}" ]]; then
        echo "[ERROR] ${var} is not set. Set it in ./cpd_vars.sh before running this script."
        exit 1
    fi
done

eval "${OC_LOGIN}"

NS="${PROJECT_CPD_INST_OPERANDS}"
CM_NAME="zen-nginx-config-cm"
DEPLOY_NAME="ibm-nginx"
OWNER_NAME="lite-cr"
OWNER_KIND="ZenService"

echo "[INFO] Target buffer sizes:"
echo "         large_client_header_buffers ${LARGE_CLIENT_HEADER_BUFFERS}"
echo "         client_header_buffer_size   ${CLIENT_HEADER_BUFFER_SIZE}"

# ── 1. Verify the ConfigMap exists and is owned by lite-cr ───────────────────

CM_EXISTS=$(oc get configmap "${CM_NAME}" -n "${NS}" --no-headers 2>/dev/null | wc -l | tr -d ' ')
if [[ "${CM_EXISTS}" -eq 0 ]]; then
    echo "[ERROR] ConfigMap '${CM_NAME}' not found in namespace '${NS}'."
    exit 1
fi

ACTUAL_OWNER=$(oc get configmap "${CM_NAME}" -n "${NS}" \
    -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null || true)
ACTUAL_OWNER_KIND=$(oc get configmap "${CM_NAME}" -n "${NS}" \
    -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null || true)

if [[ "${ACTUAL_OWNER}" != "${OWNER_NAME}" || "${ACTUAL_OWNER_KIND}" != "${OWNER_KIND}" ]]; then
    echo "[WARN] ConfigMap owner is '${ACTUAL_OWNER_KIND}/${ACTUAL_OWNER:-<none>}', expected '${OWNER_KIND}/${OWNER_NAME}'."
    echo "[WARN] Proceeding anyway - verify this is the correct ConfigMap."
fi

echo "[INFO] Found '${CM_NAME}' in namespace '${NS}' (owner: ${ACTUAL_OWNER_KIND}/${ACTUAL_OWNER})."

# ── 2. Patch http.conf ────────────────────────────────────────────────────────
# The startup script injects http.conf inline into /nginx_data/nginx.conf via:
#   sed -i "s/access_log off;/include \/etc\/config\/http[.]conf;/" /nginx_data/nginx.conf
# /nginx_data/nginx.conf already has large_client_header_buffers set (and a
# duplicate artifact from a bad template render). http.conf is included right
# after that, so we must NOT set large_client_header_buffers here - instead we
# use http.conf only for client_header_buffer_size (not present in the image).
# large_client_header_buffers is handled by patching the deployment command (step 3).

CURRENT_CONF=$(oc get configmap "${CM_NAME}" -n "${NS}" \
    -o jsonpath='{.data.http\.conf}')

PATCH_JSON=$(python3 -c "
import json, sys, re

conf = sys.stdin.read()
target = '${CLIENT_HEADER_BUFFER_SIZE}'

# Remove large_client_header_buffers if previously added (causes duplicates)
conf = re.sub(r'^\s*large_client_header_buffers\s+[^\n]*\n?', '', conf, flags=re.MULTILINE)

# Replace or insert client_header_buffer_size
pattern = r'^\s*client_header_buffer_size\s+.*$'
replacement = f'client_header_buffer_size {target};'
conf, count = re.subn(pattern, replacement, conf, flags=re.MULTILINE)
if count == 0:
    lines = conf.splitlines()
    conf = '\n'.join(lines[:1] + [replacement] + lines[1:])

print(json.dumps({'data': {'http.conf': conf}}))
" <<< "${CURRENT_CONF}")

oc patch configmap "${CM_NAME}" -n "${NS}" --type merge -p "${PATCH_JSON}"
echo "[OK]  http.conf patched (client_header_buffer_size ${CLIENT_HEADER_BUFFER_SIZE}, large_client_header_buffers removed)."

# ── 3. Patch deployment command to fix large_client_header_buffers ────────────
# /nginx_data/nginx.conf has the directive hardcoded (with a duplicate artifact).
# We inject a sed into the container command to replace all occurrences before
# startup, running before the existing /scripts/startup.sh call.
#
# The image nginx.conf has two copies:
#   line 84: large_client_header_buffers 4 32k;
#   line 87: (inside a comment-like artifact) large_client_header_buffers 4 32k;
# We replace all occurrences of the directive value to set our target.

CURRENT_CMD=$(oc get deployment "${DEPLOY_NAME}" -n "${NS}" \
    -o jsonpath='{.spec.template.spec.containers[?(@.name=="ibm-nginx-container")].command}')

TARGET_VALUE="${LARGE_CLIENT_HEADER_BUFFERS}"

# Check if already patched with our sed injection
if echo "${CURRENT_CMD}" | grep -q "large_client_header_buffers"; then
    EXISTING_VALUE=$(echo "${CURRENT_CMD}" | grep -o "large_client_header_buffers [^;]*;" | head -1 | sed 's/large_client_header_buffers //;s/;//')
    if [[ "${EXISTING_VALUE}" == "${TARGET_VALUE}" ]]; then
        echo "[INFO] Deployment already patched with large_client_header_buffers ${TARGET_VALUE}. No change needed."
    else
        echo "[INFO] Deployment patched with different value (${EXISTING_VALUE}), updating to ${TARGET_VALUE}..."
        NEEDS_DEPLOY_PATCH=true
    fi
else
    NEEDS_DEPLOY_PATCH=true
fi

if [[ "${NEEDS_DEPLOY_PATCH:-false}" == "true" ]]; then
    # Wrap the existing startup command with a sed pre-fix, replacing all
    # occurrences of large_client_header_buffers in /nginx_data/nginx.conf
    PATCH_CMD='["/bin/sh", "-c", "sed -i \"s|large_client_header_buffers [^;]*;|large_client_header_buffers '"${TARGET_VALUE}"';|g\" /nginx_data/nginx.conf && exec /scripts/startup.sh"]'

    oc patch deployment "${DEPLOY_NAME}" -n "${NS}" --type=json -p "[
      {
        \"op\": \"replace\",
        \"path\": \"/spec/template/spec/containers/0/command\",
        \"value\": ${PATCH_CMD}
      }
    ]"
    echo "[OK]  Deployment command patched (large_client_header_buffers ${TARGET_VALUE})."
fi

# ── 4. Confirm ConfigMap state ────────────────────────────────────────────────

echo ""
echo "[INFO] Resulting http.conf buffer directives:"
oc get configmap "${CM_NAME}" -n "${NS}" \
    -o jsonpath='{.data.http\.conf}' \
    | grep -E "large_client_header_buffers|client_header_buffer_size" \
    | sed 's/^/  /' || echo "  (none)"

# ── 5. Delete any crashing nginx pods so they restart cleanly ────────────────

echo ""
echo "[INFO] Removing any crashing ibm-nginx pods..."
oc get pods -n "${NS}" -l component=ibm-nginx --no-headers 2>/dev/null \
    | awk '$3 == "CrashLoopBackOff" || $3 == "Error" || $3 == "OOMKilled" {print $1}' \
    | xargs -r oc delete pod -n "${NS}" --grace-period=0 --force

# ── 6. Restart nginx deployment to pick up changes ───────────────────────────

echo ""
echo "[INFO] Restarting ibm-nginx deployment..."
oc rollout restart deployment/"${DEPLOY_NAME}" -n "${NS}"
oc rollout status deployment/"${DEPLOY_NAME}" -n "${NS}" --timeout=300s
echo "[OK]  ibm-nginx pods restarted successfully."
