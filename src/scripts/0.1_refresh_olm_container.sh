#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/source_env_setup.sh"

#---
CONTAINER_NAME="olm-utils-play-v4"

if [[ -d "${CPD_CLI_WORK_PATH}" ]]; then
    echo "[INFO] Cleaning cpd-cli workspace: ${CPD_CLI_WORK_PATH}"
    rm -rf "${CPD_CLI_WORK_PATH}"
    echo "[INFO] Workspace cleaned"
else
    echo "[INFO] Workspace already clean: ${CPD_CLI_WORK_PATH}"
fi

if podman ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "[INFO] Removing existing container: ${CONTAINER_NAME}"
    podman rm -f "${CONTAINER_NAME}"
else
    echo "[INFO] No existing container found: ${CONTAINER_NAME}"
fi

echo "[INFO] Pulling latest olm-utils image for release ${VERSION:-latest}"
podman pull --arch=amd64 "icr.io/cpopen/cpd/olm-utils-v4:${VERSION:-latest}"

echo "[INFO] Container and workspace cleaned. Run your cpd-cli manage command to start fresh."
