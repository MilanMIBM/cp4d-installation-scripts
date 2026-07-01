#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# (legacy hardcoded sourcing - replaced by universal crawl below)
# source "${SCRIPT_DIR}/../source_env_setup.sh"
# --- Universal env load: walk up to repo root (env_bootstrap.sh), source it once ---
_b="${SCRIPT_DIR}"; while [[ "${_b}" != "/" && ! -f "${_b}/env_bootstrap.sh" ]]; do _b="$(dirname "${_b}")"; done; source "${_b}/env_bootstrap.sh"; unset _b

# ---

#============================================================================
# Deploys Memgraph (graph database) into its own namespace on OpenShift and
# exposes it. Ephemeral - no PersistentVolumeClaim; the in-pod data dir is an
# emptyDir, so data is lost if the pod is rescheduled. This is intended as a
# quick standalone instance for dev/test, not durable production storage.
#
# Local parameters - adjust these to suit your environment. All can be
# overridden from the environment, e.g.:
#   MEMGRAPH_NAMESPACE=graphdb MEMGRAPH_USER=neo ./create_oc_memgraph_docker_instance.sh
#============================================================================
MEMGRAPH_NAMESPACE="${MEMGRAPH_NAMESPACE:-memgraph}"                # OpenShift project/namespace to create
MEMGRAPH_IMAGE="${MEMGRAPH_IMAGE:-memgraph/memgraph-mage}"         # container image to deploy
MEMGRAPH_SA="${MEMGRAPH_SA:-memgraph}"                            # service account for the workload
MEMGRAPH_USER="${MEMGRAPH_USER:-admin}"                           # admin username (created post-startup via Cypher)
MEMGRAPH_PASSWORD="${MEMGRAPH_PASSWORD:-}"                         # leave empty to auto-generate an 8-digit password
MEMGRAPH_BOLT_PORT="${MEMGRAPH_BOLT_PORT:-7687}"                   # bolt protocol port
MEMGRAPH_MONITORING_PORT="${MEMGRAPH_MONITORING_PORT:-7444}"       # monitoring/websocket port
MEMGRAPH_MAX_MAP_COUNT="${MEMGRAPH_MAX_MAP_COUNT:-524288}"        # kernel vm.max_map_count Memgraph requires (>=524288)
MEMGRAPH_MEM_LIMIT="${MEMGRAPH_MEM_LIMIT:-4Gi}"                    # container memory limit
MEMGRAPH_MEM_REQUEST="${MEMGRAPH_MEM_REQUEST:-1Gi}"               # container memory request
MEMGRAPH_EXPOSE_LB="${MEMGRAPH_EXPOSE_LB:-false}"                 # also create a LoadBalancer service for external bolt access
MEMGRAPH_ROLLOUT_TIMEOUT="${MEMGRAPH_ROLLOUT_TIMEOUT:-300s}"       # how long to wait for the deployment to become ready

# If OC_LOGIN is provided by the sourced env, use it to authenticate the oc client.
if [[ -n "${OC_LOGIN:-}" ]]; then
    eval "${OC_LOGIN}"
fi

# Auto-generate an 8-digit password if none was supplied.
# Note: read a fixed-size block and strip to digits rather than piping
# `tr | head`, which trips SIGPIPE (141) under `set -o pipefail` and would
# abort the script.
if [[ -z "${MEMGRAPH_PASSWORD}" ]]; then
    _rand_digits="$(LC_ALL=C tr -dc '0-9' < <(head -c 4096 /dev/urandom))"
    MEMGRAPH_PASSWORD="${_rand_digits:0:8}"
    unset _rand_digits
fi

#============================================================================
# 1. Namespace
#============================================================================
oc new-project "${MEMGRAPH_NAMESPACE}" 2>/dev/null || oc project "${MEMGRAPH_NAMESPACE}"

#============================================================================
# 2. Service account + SCCs.
#    - anyuid:     the main container runs as root (UID 0); Memgraph asserts
#                  the data dir owner equals the process EUID.
#    - privileged: the init container runs `sysctl -w vm.max_map_count` on the
#                  host; Memgraph requires >= 524288 or it crashes (exit 139).
#============================================================================
oc create serviceaccount "${MEMGRAPH_SA}" -n "${MEMGRAPH_NAMESPACE}" \
    --dry-run=client -o yaml | oc apply -f -
oc adm policy add-scc-to-user anyuid     -z "${MEMGRAPH_SA}" -n "${MEMGRAPH_NAMESPACE}"
oc adm policy add-scc-to-user privileged -z "${MEMGRAPH_SA}" -n "${MEMGRAPH_NAMESPACE}"

#============================================================================
# 3. Credentials secret (record-keeping only - NOT injected as env vars).
#    The memgraph binary maps MEMGRAPH_* env vars onto gflags and parses them
#    through std::stoi, which aborts the process. The admin user is created
#    post-startup with a Cypher query (step 7).
#============================================================================
oc create secret generic memgraph-auth -n "${MEMGRAPH_NAMESPACE}" \
    --from-literal=username="${MEMGRAPH_USER}" \
    --from-literal=password="${MEMGRAPH_PASSWORD}" \
    --dry-run=client -o yaml | oc apply -f -

#============================================================================
# 4. Deployment (ephemeral emptyDir storage) + Services.
#============================================================================
PREP_MEMGRAPH_DEPLOYMENT="cat <<EOF | oc apply -n ${MEMGRAPH_NAMESPACE} -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: memgraph
  labels:
    app: memgraph
spec:
  replicas: 1
  selector:
    matchLabels:
      app: memgraph
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: memgraph
    spec:
      serviceAccountName: ${MEMGRAPH_SA}
      initContainers:
        # Raise the host kernel limit Memgraph needs (vm.max_map_count >= 524288;
        # the OCP node default of 262144 causes a SIGSEGV crash-loop). Runs
        # privileged on the host; exits as soon as the sysctl is applied.
        - name: init-max-map-count
          image: busybox:1.36
          command: [\"sh\", \"-c\", \"sysctl -w vm.max_map_count=${MEMGRAPH_MAX_MAP_COUNT}\"]
          securityContext:
            privileged: true
            runAsUser: 0
      containers:
        - name: memgraph
          image: ${MEMGRAPH_IMAGE}
          # Run as root: Memgraph asserts the data dir owner equals the process
          # EUID. Do NOT pass flags via args: or inject MEMGRAPH_* env vars -
          # the binary maps both onto gflags and parses them via std::stoi.
          securityContext:
            runAsUser: 0
          ports:
            - name: bolt
              containerPort: ${MEMGRAPH_BOLT_PORT}
            - name: monitoring
              containerPort: ${MEMGRAPH_MONITORING_PORT}
          resources:
            requests:
              memory: \"${MEMGRAPH_MEM_REQUEST}\"
            limits:
              memory: \"${MEMGRAPH_MEM_LIMIT}\"
          volumeMounts:
            - name: memgraph-data
              mountPath: /var/lib/memgraph
            - name: memgraph-log
              mountPath: /var/log/memgraph
      volumes:
        - name: memgraph-data
          emptyDir: {}
        - name: memgraph-log
          emptyDir: {}
EOF"
eval "${PREP_MEMGRAPH_DEPLOYMENT}"

PREP_MEMGRAPH_SERVICE="cat <<EOF | oc apply -n ${MEMGRAPH_NAMESPACE} -f -
apiVersion: v1
kind: Service
metadata:
  name: memgraph-bolt
spec:
  selector:
    app: memgraph
  ports:
    - name: bolt
      port: ${MEMGRAPH_BOLT_PORT}
      targetPort: ${MEMGRAPH_BOLT_PORT}
---
apiVersion: v1
kind: Service
metadata:
  name: memgraph-monitoring
spec:
  selector:
    app: memgraph
  ports:
    - name: monitoring
      port: ${MEMGRAPH_MONITORING_PORT}
      targetPort: ${MEMGRAPH_MONITORING_PORT}
EOF"
eval "${PREP_MEMGRAPH_SERVICE}"

#============================================================================
# 5. Optional LoadBalancer service for external bolt access.
#============================================================================
if [[ "${MEMGRAPH_EXPOSE_LB}" == "true" ]]; then
    PREP_MEMGRAPH_LB="cat <<EOF | oc apply -n ${MEMGRAPH_NAMESPACE} -f -
apiVersion: v1
kind: Service
metadata:
  name: memgraph-bolt-lb
spec:
  type: LoadBalancer
  selector:
    app: memgraph
  ports:
    - name: bolt
      port: ${MEMGRAPH_BOLT_PORT}
      targetPort: ${MEMGRAPH_BOLT_PORT}
EOF"
    eval "${PREP_MEMGRAPH_LB}"
fi

#============================================================================
# 6. Wait for the deployment to roll out.
#============================================================================
oc rollout status deployment/memgraph -n "${MEMGRAPH_NAMESPACE}" --timeout="${MEMGRAPH_ROLLOUT_TIMEOUT}"

#============================================================================
# 7. Create the admin user via Cypher (Memgraph v3 has no env-var bootstrap).
#    NOTE: once any user exists, Memgraph enforces auth on all connections.
#============================================================================
MEMGRAPH_POD="$(oc get pod -n "${MEMGRAPH_NAMESPACE}" -l app=memgraph -o jsonpath='{.items[0].metadata.name}')"
echo "CREATE USER ${MEMGRAPH_USER} IDENTIFIED BY '${MEMGRAPH_PASSWORD}'; GRANT ALL PRIVILEGES TO ${MEMGRAPH_USER};" \
    | oc exec -i -n "${MEMGRAPH_NAMESPACE}" "${MEMGRAPH_POD}" -- mgconsole \
    || echo "[WARN] Could not create admin user automatically; create it manually via mgconsole."

#============================================================================
# 8. Print connection details.
#============================================================================
echo ""
echo "=================== MEMGRAPH READY ==================="
echo "  Namespace : ${MEMGRAPH_NAMESPACE}"
echo "  Image     : ${MEMGRAPH_IMAGE}"
echo "  Bolt svc  : memgraph-bolt.${MEMGRAPH_NAMESPACE}.svc.cluster.local:${MEMGRAPH_BOLT_PORT}"
echo "  Monitoring: memgraph-monitoring.${MEMGRAPH_NAMESPACE}.svc.cluster.local:${MEMGRAPH_MONITORING_PORT}"
echo "  Username  : ${MEMGRAPH_USER}"
echo "  Password  : ${MEMGRAPH_PASSWORD}"
echo "  Storage   : ephemeral (emptyDir - data lost on pod reschedule)"
[[ "${MEMGRAPH_EXPOSE_LB}" == "true" ]] && \
echo "  LB svc    : memgraph-bolt-lb (run 'oc get svc memgraph-bolt-lb -n ${MEMGRAPH_NAMESPACE}' for the external IP)"
echo "  Local fwd : oc port-forward -n ${MEMGRAPH_NAMESPACE} deploy/memgraph ${MEMGRAPH_BOLT_PORT}:${MEMGRAPH_BOLT_PORT} ${MEMGRAPH_MONITORING_PORT}:${MEMGRAPH_MONITORING_PORT}"
echo "======================================================"
