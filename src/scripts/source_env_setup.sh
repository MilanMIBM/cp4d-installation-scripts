#!/bin/zsh
# Sourceable env setup - use from any script in src/scripts/*/: source "$(dirname $0)/../source_env_setup.sh"
# Guard against double-sourcing
[[ -n "${_CP4D_ENV_LOADED:-}" ]] && return 0
_CP4D_ENV_LOADED=1

_ENV_SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export CONFIG_DIR="${_ENV_SETUP_DIR}/../../cp4d_config"
export SERVICE_INSTANCE_FILE_DIR="${_ENV_SETUP_DIR}/../../service_instances"
unset _ENV_SETUP_DIR

_sourced=()
_source_if_exists() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    local real; real="$(cd "$(dirname "$f")" && pwd)/$(basename "$f")"
    for s in "${_sourced[@]:-}"; do [[ "$s" == "$real" ]] && return 0; done
    _sourced+=("$real")
    source "$real"
}

_source_if_exists "${CONFIG_DIR}/cpd_vars.sh"
_source_if_exists "${CONFIG_DIR}/cpd_instance_details.sh"
for _f in "${CONFIG_DIR}"/*.sh; do
    _source_if_exists "$_f"
done
unset _f _sourced
unset -f _source_if_exists

export CPD_CLI_MANAGE_WORKSPACE="$HOME/cpd-cli"
export PATH="$HOME/cpd-cli:$PATH"
export CPD_CLI_WORK_PATH="$HOME/cpd-cli/work"
export CPD_CLI_WORK_PATH_CONTAINER="/tmp/work"
export CPD_CONFIG_PATH_CONTAINER="/cp4d_config"

# Copy cp4d_config files into the work directory so the container can read them at /tmp/work/cp4d_config/
_CONFIG_WORK_DIR="${CPD_CLI_WORK_PATH}/cp4d_config"
mkdir -p "${_CONFIG_WORK_DIR}"
cp "${CONFIG_DIR}/"* "${_CONFIG_WORK_DIR}/" 2>/dev/null || true
unset _CONFIG_WORK_DIR

# Override CPD_CONFIG_PATH_CONTAINER to point at the copied location inside the container
export CPD_CONFIG_PATH_CONTAINER="/tmp/work/cp4d_config"

# -----------------------------------------------------------------------------
# Cluster API DNS pinning
# -----------------------------------------------------------------------------
# The OpenShift API hostname is served by upstream DNS that resolves
# intermittently, and the podman VM's own resolver often cannot resolve it at
# all. Every cpd-cli/oc call then dies with "dial tcp: lookup <api host> ...
# i/o timeout" even though the cluster is up and 6443 is reachable.
#
# Fix: resolve the host once here, from a resolver that answers reliably, and
# pin the result so DNS is never consulted again:
#   - --add-host on the olm-utils container (via OLM_UTILS_LAUNCH_ARGS)
#   - an /etc/hosts entry inside an already-running container, since cpd-cli
#     reuses it and it would otherwise keep the old, resolver-only view
#
# Set CP4D_SKIP_DNS_PIN=1 to opt out entirely.
_cp4d_pin_api_dns() {
    [[ -n "${CP4D_SKIP_DNS_PIN:-}" ]] && return 0
    [[ -n "${OCP_URL:-}" ]] || return 0

    # Strip scheme and port to get the bare hostname.
    local host="${OCP_URL#*://}"
    host="${host%%/*}"
    host="${host%%:*}"
    [[ -n "${host}" ]] || return 0

    # An IP literal needs no resolving.
    if [[ "${host}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi

    # Allow a manual override when DNS is unusable everywhere.
    local ip="${OCP_API_IP:-}"

    # Try resolvers in order: the system one first (it may be authoritative for
    # private clusters), then public resolvers as a fallback. Short timeouts so
    # a dead resolver costs ~2s, not the 20s the cpd-cli call would burn.
    if [[ -z "${ip}" ]]; then
        local r
        for r in "" "1.1.1.1" "8.8.8.8"; do
            if [[ -z "$r" ]]; then
                ip="$(dig +short +time=2 +tries=1 "${host}" A 2>/dev/null | grep -m1 -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')"
            else
                ip="$(dig +short +time=2 +tries=1 "${host}" A "@${r}" 2>/dev/null | grep -m1 -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')"
            fi
            [[ -n "${ip}" ]] && break
        done
    fi

    if [[ -z "${ip}" ]]; then
        echo "[WARN] Could not resolve ${host}; leaving DNS to the container." >&2
        echo "[WARN] If this keeps failing, set OCP_API_IP=<ip> to pin it manually." >&2
        return 0
    fi

    export OCP_API_HOST="${host}"
    export OCP_API_IP="${ip}"

    # Pin for containers launched from here on.
    case " ${OLM_UTILS_LAUNCH_ARGS:-} " in
        *" --add-host=${host}:"*) ;;
        *) export OLM_UTILS_LAUNCH_ARGS="${OLM_UTILS_LAUNCH_ARGS:+${OLM_UTILS_LAUNCH_ARGS} }--add-host=${host}:${ip}" ;;
    esac

    # Pin inside the already-running container, which cpd-cli reuses as-is.
    local engine=""
    command -v podman >/dev/null 2>&1 && engine="podman"
    [[ -z "${engine}" ]] && command -v docker >/dev/null 2>&1 && engine="docker"
    if [[ -n "${engine}" ]] && "${engine}" ps --format '{{.Names}}' 2>/dev/null | grep -qx 'olm-utils-play-v4'; then
        if ! "${engine}" exec olm-utils-play-v4 grep -qE "^${ip}[[:space:]]+${host}\$" /etc/hosts 2>/dev/null; then
            # Drop any stale entry for this host, then append the current one.
            # Runs as root because the container's default user cannot write /etc/hosts.
            "${engine}" exec --user 0 olm-utils-play-v4 sh -c \
                "grep -v '[[:space:]]${host}\$' /etc/hosts > /tmp/.hosts.new && printf '%s\t%s\n' '${ip}' '${host}' >> /tmp/.hosts.new && cat /tmp/.hosts.new > /etc/hosts && rm -f /tmp/.hosts.new" \
                >/dev/null 2>&1 \
                && echo "[INFO] Pinned ${host} -> ${ip} in olm-utils container" \
                || echo "[WARN] Could not pin ${host} in the running olm-utils container" >&2
        fi
    fi
}
_cp4d_pin_api_dns
unset -f _cp4d_pin_api_dns
