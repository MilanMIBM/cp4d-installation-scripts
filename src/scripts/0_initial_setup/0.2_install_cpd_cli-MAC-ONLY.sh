#!/bin/zsh
# cpd-cli Auto-Installer for macOS
#
# The cpd-cli version is derived from ${VERSION} (the IBM Software Hub release
# in cp4d_config/cpd_vars.sh), because the binary is version-locked to a SWH
# release and launches its olm-utils container from that built-in version,
# ignoring ${OLM_UTILS_IMAGE}. Installing a mismatched cpd-cli is what leaves
# you running, say, a 5.3.1 olm-utils container against a 5.4.0 config.
#
# Usage: ./0.2_install_cpd_cli-MAC-ONLY.sh [SE|EE] [--swh X.Y.Z] [--patch N]
#
#   [SE|EE]          Edition (default: EE)
#   --swh X.Y.Z      Install for this SWH version instead of ${VERSION}.
#                    Needed on a fresh machine where cpd_vars.sh does not exist.
#   --patch N        Pin an exact cpd-cli patch (default: newest for the version)
#   --list           Show the cpd-cli releases available and exit
#
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Find the repo root (marked by env_bootstrap.sh) so the shared resolver can be
# sourced. The env itself is loaded best-effort: this script has to work on a
# fresh machine where cp4d_config/cpd_vars.sh does not exist yet, so a missing
# env is only fatal when no --swh was passed either.
_REPO_ROOT="${SCRIPT_DIR}"
while [[ "${_REPO_ROOT}" != "/" && ! -f "${_REPO_ROOT}/env_bootstrap.sh" ]]; do
    _REPO_ROOT="$(dirname "${_REPO_ROOT}")"
done

EDITION=""
SWH_OVERRIDE=""
PIN_PATCH=""
LIST_ONLY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        SE|EE)        EDITION="$1"; shift ;;
        --swh)        SWH_OVERRIDE="${2:-}"; shift 2 ;;
        --patch)      PIN_PATCH="${2:-}"; shift 2 ;;
        --list)       LIST_ONLY=1; shift ;;
        -h|--help)    sed -n '2,17p' "$0"; exit 0 ;;
        *) echo "[ERROR] Unknown argument: $1 (try --help)"; exit 1 ;;
    esac
done
EDITION="${EDITION:-EE}"

if [[ -f "${_REPO_ROOT}/env_bootstrap.sh" ]]; then
    source "${_REPO_ROOT}/env_bootstrap.sh" || true
    source "${_REPO_ROOT}/src/helpers/resolve_cpd_cli_release.sh"
else
    echo "[ERROR] Could not locate the repo root (env_bootstrap.sh)."
    exit 1
fi

SWH_VERSION="${SWH_OVERRIDE:-${VERSION:-}}"
if [[ -z "${SWH_VERSION}" ]]; then
    echo "[ERROR] No Software Hub version available."
    echo "[ERROR] Set VERSION in cp4d_config/cpd_vars.sh, or pass --swh X.Y.Z."
    exit 1
fi

ASSET_PLATFORM="$(cpd_cli_platform_asset)"
if [[ "${ASSET_PLATFORM}" != "darwin" ]]; then
    echo "[ERROR] This installer is macOS-only (detected: ${ASSET_PLATFORM})."
    exit 1
fi

INSTALL_DIR="${HOME}/cpd-cli"

echo "=== cpd-cli Installer for macOS - Software Hub ${SWH_VERSION} (${EDITION}) ==="

# -----------------------------------------------------------------------------
# Resolve which cpd-cli release matches this Software Hub version.
# -----------------------------------------------------------------------------
echo "[1/5] Resolving the cpd-cli release for SWH ${SWH_VERSION}..."

if (( LIST_ONLY )); then
    _LIST="$(cpd_cli_resolve_release "${SWH_VERSION}" "${ASSET_PLATFORM}" "${EDITION}" "" 1)" || exit 1
    echo "[INFO] cpd-cli releases available for SWH ${SWH_VERSION}:"
    echo "${_LIST}" | awk -F'\t' '$1=="AVAILABLE" { printf "  %-14s patch %-3s %s\n", $2, $3, $4 }'
    exit 0
fi

_RESOLVED="$(cpd_cli_resolve_release "${SWH_VERSION}" "${ASSET_PLATFORM}" "${EDITION}" "${PIN_PATCH}")" || {
    echo "[ERROR] Could not resolve a cpd-cli release (see message above)."
    exit 1
}

RELEASE_TAG="$(cpd_cli_field "${_RESOLVED}" TAG)"
RELEASE_PATCH="$(cpd_cli_field "${_RESOLVED}" PATCH)"
CPD_CLI_VERSION="$(cpd_cli_field "${_RESOLVED}" CLI_VERSION)"
PACKAGE_NAME="$(cpd_cli_field "${_RESOLVED}" ASSET)"
DOWNLOAD_URL="$(cpd_cli_field "${_RESOLVED}" URL)"
ALL_PATCHES="$(cpd_cli_field "${_RESOLVED}" OTHERS)"

echo "[INFO] Selected ${RELEASE_TAG} (cpd-cli ${CPD_CLI_VERSION}, patch ${RELEASE_PATCH})"
echo "[INFO] Available patches for ${SWH_VERSION}: ${ALL_PATCHES}"
if [[ -n "${PATCH_ID:-}" && -z "${PIN_PATCH}" ]]; then
    echo "[INFO] PATCH_ID=${PATCH_ID} applies to olm-utils/CASE, not cpd-cli; ignoring it here."
fi

if [[ -x "${INSTALL_DIR}/cpd-cli" ]]; then
    echo "[WARN] An existing cpd-cli is present at ${INSTALL_DIR}."
    echo "[WARN] This installer overwrites it. To upgrade an existing install"
    echo "[WARN] (keeps work/, clears the stale olm-utils container), use:"
    echo "[WARN]   src/utils/cpd-cli_upgrade_to_version.sh"
fi

# -----------------------------------------------------------------------------
# Download
# -----------------------------------------------------------------------------
echo "[2/5] Downloading ${PACKAGE_NAME} (${RELEASE_TAG})..."
_TMP_TGZ="$(mktemp -t cpd-cli-pkg)"
trap 'rm -f "${_TMP_TGZ}"; (( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

curl -fSL --retry 3 --retry-delay 2 -o "${_TMP_TGZ}" "${DOWNLOAD_URL}"

# Verify the archive before it is allowed to overwrite anything.
if ! tar -tzf "${_TMP_TGZ}" >/dev/null 2>&1; then
    echo "[ERROR] Downloaded archive is not a readable gzip tarball: ${PACKAGE_NAME}"
    exit 1
fi

# -----------------------------------------------------------------------------
# Extract
# -----------------------------------------------------------------------------
echo "[3/5] Extracting to ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"
tar -xzf "${_TMP_TGZ}" -C "${INSTALL_DIR}" --strip-components=1

# -----------------------------------------------------------------------------
# Trust components via xattr (removes quarantine flag, no manual right-click needed)
# -----------------------------------------------------------------------------
echo "[4/5] Removing macOS quarantine flags..."
xattr -rd com.apple.quarantine "${INSTALL_DIR}" 2>/dev/null || true

chmod +x "${INSTALL_DIR}/cpd-cli" 2>/dev/null || true
for _p in "${INSTALL_DIR}"/plugins/lib/*/*; do
    [[ -f "${_p}" ]] && chmod +x "${_p}" 2>/dev/null || true
done
unset _p

# -----------------------------------------------------------------------------
# Add to PATH
# -----------------------------------------------------------------------------
echo "[5/5] Configuring PATH..."
EXPORT_LINE="export PATH=\"${INSTALL_DIR}:\$PATH\""

SHELL_RC=""
if [[ -f "${HOME}/.zshrc" ]]; then
  SHELL_RC="${HOME}/.zshrc"
elif [[ -f "${HOME}/.bash_profile" ]]; then
  SHELL_RC="${HOME}/.bash_profile"
else
  SHELL_RC="${HOME}/.zshrc"
  touch "${SHELL_RC}"
fi

if ! grep -qF "cpd-cli" "${SHELL_RC}"; then
  echo "" >> "${SHELL_RC}"
  echo "# IBM cpd-cli" >> "${SHELL_RC}"
  echo "${EXPORT_LINE}" >> "${SHELL_RC}"
  echo "Added cpd-cli to PATH in ${SHELL_RC}"
else
  echo "PATH entry already exists in ${SHELL_RC}, skipping."
fi

# Optional: set workspace env var
WORKSPACE_LINE="export CPD_CLI_MANAGE_WORKSPACE=\"${INSTALL_DIR}\""
if ! grep -qF "CPD_CLI_MANAGE_WORKSPACE" "${SHELL_RC}"; then
  echo "${WORKSPACE_LINE}" >> "${SHELL_RC}"
fi

# -----------------------------------------------------------------------------
# Verify
# -----------------------------------------------------------------------------
export PATH="${INSTALL_DIR}:$PATH"

NEW_OUT="$("${INSTALL_DIR}/cpd-cli" version 2>/dev/null || true)"
NEW_SWH="$(echo "${NEW_OUT}" | awk -F': *' '/SWH Release Version:/ { print $2; exit }')"
NEW_CLI="$(echo "${NEW_OUT}" | awk -F': *' '/^[[:space:]]*Version:/ { print $2; exit }')"

echo ""
echo "=== Installation complete ==="
echo "  Installed:   cpd-cli ${NEW_CLI:-${CPD_CLI_VERSION}} (SWH ${NEW_SWH:-unknown})"
echo "  Release:     ${RELEASE_TAG}"
echo "  Location:    ${INSTALL_DIR}"
echo ""
echo "Run 'source ${SHELL_RC}' or open a new terminal, then verify with:"
echo "  cpd-cli version"

if [[ -n "${NEW_SWH}" && "${NEW_SWH}" != "${SWH_VERSION}" ]]; then
    echo ""
    echo "[WARN] The installed binary reports SWH ${NEW_SWH} but ${SWH_VERSION} was requested."
    echo "[WARN] Check that the version is a published SWH release."
    exit 1
fi
