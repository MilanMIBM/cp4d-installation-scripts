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
# Confluent Platform - install
# ------------------------------------------------------------------------------
# Deploys the cp-all-in-one topology (KRaft variant) onto OpenShift:
#   broker (KRaft, combined broker+controller) -> schema-registry -> connect
#   -> ksqldb-server -> rest-proxy -> control-center
#
# Image tags, ports and environment variable names mirror the upstream
# docker-compose file at https://github.com/confluentinc/cp-all-in-one so the
# mapping between the two stays legible. Component selection and sizing come
# from cp4d_config/confluent_vars.sh.
#
# Run 1.0_confluent_prep.sh first.
# ==============================================================================

eval "${OC_LOGIN}"

NS="${PROJECT_CONFLUENT_SERVER}"
SA="confluent"

if ! oc get namespace "${NS}" &>/dev/null; then
    echo "[ERROR] Project '${NS}' does not exist. Run 1.0_confluent_prep.sh first." >&2
    exit 1
fi
if ! oc get serviceaccount confluent -n "${NS}" &>/dev/null; then
    echo "[ERROR] ServiceAccount 'confluent' not found in ${NS}. Run 1.0_confluent_prep.sh first." >&2
    exit 1
fi
oc project "${NS}" >/dev/null

# Set by 0_confluent_prepare_template_config.sh; default for configs written
# before that script existed.
: "${CONFLUENT_MIN_INSYNC_REPLICAS:=1}"
# Defaults for configs written before the 8.2.0 / next-gen-C3 topology landed.
: "${CONFLUENT_BROKER_IMAGE:=${CONFLUENT_REGISTRY}/cp-server:${CONFLUENT_VERSION}}"
: "${CONFLUENT_C3_VERSION:=2.5.0}"
: "${CONFLUENT_CONTROL_CENTER_IMAGE:=${CONFLUENT_REGISTRY}/cp-enterprise-control-center-next-gen:${CONFLUENT_C3_VERSION}}"
: "${CONFLUENT_PROMETHEUS_IMAGE:=${CONFLUENT_REGISTRY}/cp-enterprise-prometheus:${CONFLUENT_C3_VERSION}}"
: "${CONFLUENT_ALERTMANAGER_IMAGE:=${CONFLUENT_REGISTRY}/cp-enterprise-alertmanager:${CONFLUENT_C3_VERSION}}"
: "${CONFLUENT_BROKER_JMX_PORT:=9101}"
: "${CONFLUENT_PROMETHEUS_PORT:=9090}"
: "${CONFLUENT_ALERTMANAGER_PORT:=9093}"
: "${CONFLUENT_AUTH_ENABLED:=true}"
: "${CONFLUENT_AUTH_SECRET:=confluent-auth}"

# ------------------------------------------------------------------------------
# Basic-auth credentials, provisioned by 1.0_confluent_prep.sh
# ------------------------------------------------------------------------------
# Read back from the secret rather than regenerated here, so repeated installs
# keep the same credentials. The bcrypt hash feeds the Prometheus/Alertmanager
# web configs; the plaintext password feeds C3's JAAS property file (Jetty's
# PropertyFileLoginModule has no bcrypt support) and Prometheus scrape configs.
AUTH_USER=""
AUTH_PASS=""
AUTH_BCRYPT=""
if [[ "${CONFLUENT_AUTH_ENABLED}" == "true" ]]; then
    AUTH_USER="$(oc get secret "${CONFLUENT_AUTH_SECRET}" -n "${NS}" -o jsonpath='{.data.username}' 2>/dev/null | base64 --decode || true)"
    AUTH_PASS="$(oc get secret "${CONFLUENT_AUTH_SECRET}" -n "${NS}" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || true)"
    AUTH_BCRYPT="$(oc get secret "${CONFLUENT_AUTH_SECRET}" -n "${NS}" -o jsonpath='{.data.bcrypt}' 2>/dev/null | base64 --decode || true)"

    if [[ -z "${AUTH_USER}" || -z "${AUTH_PASS}" || -z "${AUTH_BCRYPT}" ]]; then
        echo "[ERROR] CONFLUENT_AUTH_ENABLED=true but secret '${CONFLUENT_AUTH_SECRET}' is missing or incomplete in ${NS}." >&2
        echo "[ERROR] Run 1.0_confluent_prep.sh first." >&2
        exit 1
    fi
    echo "[INFO] Basic auth enabled for the web UIs (user: ${AUTH_USER})."
else
    echo "[WARN] CONFLUENT_AUTH_ENABLED=false - web UIs will be deployed without authentication."
fi

PROM_URL="http://prometheus:${CONFLUENT_PROMETHEUS_PORT}"
ALERTMANAGER_URL="http://alertmanager:${CONFLUENT_ALERTMANAGER_PORT}"

# Bootstrap on the headless service: it resolves to all broker pod IPs, and
# the PLAINTEXT listener advertises per-pod FQDNs, so a client can reach the
# specific partition leader. The 'broker' ClusterIP + PLAINTEXT_HOST pair
# cannot: that listener advertises the service name for every broker, so a
# leader-directed produce lands on a random pod (NOT_LEADER_OR_FOLLOWER).
BOOTSTRAP="broker-headless:${CONFLUENT_BROKER_INTERNAL_PORT}"
SR_URL="http://schema-registry:${CONFLUENT_SCHEMA_REGISTRY_PORT}"

# Rendered YAML is collected here so a failure leaves the manifests inspectable.
MANIFEST_DIR="${SCRIPT_DIR}/confluent_platform_vars/rendered"
mkdir -p "${MANIFEST_DIR}"

# ------------------------------------------------------------------------------
# apply_component <name> - reads a manifest on stdin, writes it to MANIFEST_DIR
# and applies it.
# ------------------------------------------------------------------------------
apply_component() {
    local name="$1"
    local file="${MANIFEST_DIR}/${name}.yaml"
    cat > "${file}"
    oc apply -f "${file}"
    echo "[INFO] Applied ${name} (manifest: ${file})."
}

# ------------------------------------------------------------------------------
# expose_route <name> <port> - creates a route when routes are enabled.
# ------------------------------------------------------------------------------
expose_route() {
    local name="$1" port="$2"
    [[ "${CONFLUENT_CREATE_ROUTES}" == "true" ]] || return 0

    local host_line=""
    [[ -n "${CONFLUENT_ROUTE_DOMAIN:-}" ]] && host_line="  host: ${name}-${NS}.${CONFLUENT_ROUTE_DOMAIN}"

    oc apply -f - <<EOF
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ${name}
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
${host_line}
  to:
    kind: Service
    name: ${name}
  port:
    targetPort: ${port}
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF
}

# ------------------------------------------------------------------------------
# wait_rollout <name> - waits for a workload to become available.
# ------------------------------------------------------------------------------
wait_rollout() {
    local kind="$1" name="$2"
    echo "[INFO] Waiting for ${kind}/${name} to roll out..."
    oc rollout status "${kind}/${name}" -n "${NS}" --timeout="${CONFLUENT_ROLLOUT_TIMEOUT}"
}

# ==============================================================================
# Broker (KRaft: combined broker + controller, no ZooKeeper)
# ==============================================================================
# Metric allow-list for the telemetry exporter, copied verbatim from the
# upstream cp-all-in-one compose. It is what next-gen Control Center's
# dashboards query; trimming it blanks panels in the UI.
_telemetry_metrics_include='io.confluent.kafka.server.request.(?!.*delta).*|io.confluent.kafka.server.server.broker.state|io.confluent.kafka.server.replica.manager.leader.count|io.confluent.kafka.server.request.queue.size|io.confluent.kafka.server.broker.topic.failed.produce.requests.rate.1.min|io.confluent.kafka.server.tier.archiver.total.lag|io.confluent.kafka.server.request.total.time.ms.p99|io.confluent.kafka.server.broker.topic.failed.fetch.requests.rate.1.min|io.confluent.kafka.server.broker.topic.total.fetch.requests.rate.1.min|io.confluent.kafka.server.partition.caught.up.replicas.count|io.confluent.kafka.server.partition.observer.replicas.count|io.confluent.kafka.server.tier.tasks.num.partitions.in.error|io.confluent.kafka.server.broker.topic.bytes.out.rate.1.min|io.confluent.kafka.server.request.total.time.ms.p95|io.confluent.kafka.server.controller.active.controller.count|io.confluent.kafka.server.request.total.time.ms.p999|io.confluent.kafka.server.controller.active.broker.count|io.confluent.kafka.server.request.handler.pool.request.handler.avg.idle.percent.rate.1.min|io.confluent.kafka.server.controller.unclean.leader.elections.rate.1.min|io.confluent.kafka.server.replica.manager.partition.count|io.confluent.kafka.server.controller.unclean.leader.elections.total|io.confluent.kafka.server.partition.replicas.count|io.confluent.kafka.server.broker.topic.total.produce.requests.rate.1.min|io.confluent.kafka.server.controller.offline.partitions.count|io.confluent.kafka.server.socket.server.network.processor.avg.idle.percent|io.confluent.kafka.server.partition.under.replicated|io.confluent.kafka.server.log.log.start.offset|io.confluent.kafka.server.log.tier.size|io.confluent.kafka.server.log.size|io.confluent.kafka.server.tier.fetcher.bytes.fetched.total|io.confluent.kafka.server.request.total.time.ms.p50|io.confluent.kafka.server.tenant.consumer.lag.offsets|io.confluent.kafka.server.log.log.end.offset|io.confluent.kafka.server.broker.topic.bytes.in.rate.1.min|io.confluent.kafka.server.partition.under.min.isr|io.confluent.kafka.server.partition.in.sync.replicas.count|io.confluent.telemetry.http.exporter.batches.dropped|io.confluent.telemetry.http.exporter.items.total|io.confluent.telemetry.http.exporter.items.succeeded|io.confluent.telemetry.http.exporter.send.time.total.millis|io.confluent.kafka.server.controller.leader.election.rate.(?!.*delta).*|io.confluent.telemetry.http.exporter.batches.failed'

_quorum_voters=""
for i in $(seq 0 $(( CONFLUENT_BROKER_REPLICAS - 1 ))); do
    [[ -n "${_quorum_voters}" ]] && _quorum_voters+=","
    _quorum_voters+="$(( i + 1 ))@broker-${i}.broker-headless.${NS}.svc.cluster.local:${CONFLUENT_BROKER_CONTROLLER_PORT}"
done

apply_component broker <<EOF
apiVersion: v1
kind: Service
metadata:
  name: broker-headless
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  clusterIP: None
  # Without this a headless service only publishes DNS for Ready endpoints,
  # and the brokers deadlock: none turns Ready until the KRaft quorum forms,
  # and the quorum cannot form until they resolve each other's peer names.
  publishNotReadyAddresses: true
  selector:
    app: broker
  ports:
    - name: internal
      port: ${CONFLUENT_BROKER_INTERNAL_PORT}
    - name: controller
      port: ${CONFLUENT_BROKER_CONTROLLER_PORT}
---
apiVersion: v1
kind: Service
metadata:
  name: broker
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: broker
  ports:
    - name: internal
      port: ${CONFLUENT_BROKER_INTERNAL_PORT}
      targetPort: ${CONFLUENT_BROKER_INTERNAL_PORT}
    - name: external
      port: ${CONFLUENT_BROKER_EXTERNAL_PORT}
      targetPort: ${CONFLUENT_BROKER_EXTERNAL_PORT}
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: broker
  namespace: ${NS}
  labels:
    app: broker
    app.kubernetes.io/part-of: confluent
spec:
  serviceName: broker-headless
  replicas: ${CONFLUENT_BROKER_REPLICAS}
  # KRaft brokers form a quorum, so they must come up together: with the
  # default OrderedReady policy broker-0 never turns Ready (a 3-voter quorum
  # needs 2 members), so broker-1 is never created and the rollout deadlocks.
  podManagementPolicy: Parallel
  selector:
    matchLabels:
      app: broker
  template:
    metadata:
      labels:
        app: broker
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      # The cp-* images run as uid 1000 (appuser). anyuid permits that uid but
      # does not touch volume ownership, so a freshly provisioned PV mounts
      # root-owned and the image's "is /var/lib/kafka/data writable" preflight
      # fails. fsGroup makes the kubelet chgrp the volume to 1000 and set the
      # setgid bit, which is what makes the mount writable for appuser.
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      containers:
        - name: broker
          image: ${CONFLUENT_BROKER_IMAGE}
          ports:
            - containerPort: ${CONFLUENT_BROKER_INTERNAL_PORT}
            - containerPort: ${CONFLUENT_BROKER_CONTROLLER_PORT}
            - containerPort: ${CONFLUENT_BROKER_EXTERNAL_PORT}
            - containerPort: ${CONFLUENT_BROKER_JMX_PORT}
          env:
            # Derive the KRaft node id from the ordinal in the StatefulSet name.
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: KAFKA_PROCESS_ROLES
              value: 'broker,controller'
            - name: KAFKA_LISTENER_SECURITY_PROTOCOL_MAP
              value: 'CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT'
            - name: KAFKA_INTER_BROKER_LISTENER_NAME
              value: 'PLAINTEXT'
            - name: KAFKA_CONTROLLER_LISTENER_NAMES
              value: 'CONTROLLER'
            - name: KAFKA_CONTROLLER_QUORUM_VOTERS
              value: '${_quorum_voters}'
            - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: KAFKA_TRANSACTION_STATE_LOG_MIN_ISR
              value: '${CONFLUENT_MIN_INSYNC_REPLICAS}'
            - name: KAFKA_MIN_INSYNC_REPLICAS
              value: '${CONFLUENT_MIN_INSYNC_REPLICAS}'
            - name: KAFKA_DEFAULT_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS
              value: '0'
            - name: KAFKA_NUM_PARTITIONS
              value: '${CONFLUENT_PARTITIONS}'
            # A subdirectory of the mount, not the mount root: ext4 volumes
            # carry a lost+found at their root, and the LogManager rejects any
            # entry in a log dir that is not a topic-partition.
            - name: KAFKA_LOG_DIRS
              value: '/var/lib/kafka/data/logs'
            - name: CLUSTER_ID
              value: '${CONFLUENT_CLUSTER_ID}'
            - name: KAFKA_CONFLUENT_SCHEMA_REGISTRY_URL
              value: '${SR_URL}'
            - name: CONFLUENT_METRICS_ENABLE
              value: 'true'
            - name: CONFLUENT_SUPPORT_CUSTOMER_ID
              value: 'anonymous'
            - name: KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: KAFKA_CONFLUENT_CONSUMER_LAG_EMITTER_ENABLED
              value: 'true'
            # --- Telemetry -> Prometheus (what next-gen Control Center reads) ---
            # cp-server only; the reporter is absent from the community cp-kafka
            # image. Writes OTLP straight into C3's Prometheus, no scraping.
            - name: KAFKA_METRIC_REPORTERS
              value: 'io.confluent.telemetry.reporter.TelemetryReporter'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_TYPE
              value: 'http'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_ENABLED
              value: 'true'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_CLIENT_BASE_URL
              value: '${PROM_URL}/api/v1/otlp'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_CLIENT_COMPRESSION
              value: 'gzip'
            # The exporter requires credentials to be set; Confluent's own
            # compose passes literal dummies since local Prometheus takes none.
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_API_KEY
              value: 'dummy'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_API_SECRET
              value: 'dummy'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_BUFFER_PENDING_BATCHES_MAX
              value: '80'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_BUFFER_BATCH_ITEMS_MAX
              value: '4000'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_BUFFER_INFLIGHT_SUBMISSIONS_MAX
              value: '10'
            - name: KAFKA_CONFLUENT_TELEMETRY_METRICS_COLLECTOR_INTERVAL_MS
              value: '60000'
            - name: KAFKA_CONFLUENT_TELEMETRY_REMOTECONFIG_CONFLUENT_ENABLED
              value: 'false'
            - name: KAFKA_CONFLUENT_TELEMETRY_EXPORTER_C3PLUSPLUS_METRICS_INCLUDE
              value: '${_telemetry_metrics_include}'
          command:
            - /bin/bash
            - -c
            - |
              set -e
              mkdir -p /var/lib/kafka/data/logs
              ORDINAL="\${POD_NAME##*-}"
              export KAFKA_NODE_ID="\$(( ORDINAL + 1 ))"
              FQDN="\${POD_NAME}.broker-headless.${NS}.svc.cluster.local"
              export KAFKA_LISTENERS="PLAINTEXT://0.0.0.0:${CONFLUENT_BROKER_INTERNAL_PORT},CONTROLLER://0.0.0.0:${CONFLUENT_BROKER_CONTROLLER_PORT},PLAINTEXT_HOST://0.0.0.0:${CONFLUENT_BROKER_EXTERNAL_PORT}"
              export KAFKA_ADVERTISED_LISTENERS="PLAINTEXT://\${FQDN}:${CONFLUENT_BROKER_INTERNAL_PORT},PLAINTEXT_HOST://broker:${CONFLUENT_BROKER_EXTERNAL_PORT}"
              # JMX must advertise the pod's own name, not localhost, or remote
              # JMX clients get an unreachable stub address.
              export KAFKA_JMX_PORT="${CONFLUENT_BROKER_JMX_PORT}"
              export KAFKA_JMX_HOSTNAME="\${FQDN}"
              exec /etc/confluent/docker/run
          volumeMounts:
            - name: confluent-broker-data
              mountPath: /var/lib/kafka/data
          readinessProbe:
            tcpSocket:
              port: ${CONFLUENT_BROKER_INTERNAL_PORT}
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 30
          resources:
            requests:
              cpu: "${CONFLUENT_BROKER_CPU_REQUEST}"
              memory: "${CONFLUENT_BROKER_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_BROKER_CPU_LIMIT}"
              memory: "${CONFLUENT_BROKER_MEM_LIMIT}"
  # One PVC per broker. A shared ReadWriteOnce claim cannot back more than one
  # replica, and each Kafka broker needs its own log dir regardless.
  volumeClaimTemplates:
    - metadata:
        name: confluent-broker-data
        labels:
          app.kubernetes.io/part-of: confluent
      spec:
        accessModes:
          - ReadWriteOnce
        storageClassName: ${CONFLUENT_STORAGE_CLASS}
        resources:
          requests:
            storage: ${CONFLUENT_BROKER_STORAGE_SIZE}
EOF

wait_rollout statefulset broker

# ==============================================================================
# Schema Registry
# ==============================================================================
if [[ "${CONFLUENT_INSTALL_SCHEMA_REGISTRY}" == "true" ]]; then
    apply_component schema-registry <<EOF
apiVersion: v1
kind: Service
metadata:
  name: schema-registry
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: schema-registry
  ports:
    - name: http
      port: ${CONFLUENT_SCHEMA_REGISTRY_PORT}
      targetPort: ${CONFLUENT_SCHEMA_REGISTRY_PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: schema-registry
  namespace: ${NS}
  labels:
    app: schema-registry
    app.kubernetes.io/part-of: confluent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: schema-registry
  template:
    metadata:
      labels:
        app: schema-registry
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      # The service named 'schema-registry' makes Kubernetes inject
      # SCHEMA_REGISTRY_PORT=tcp://<ip>:8081. The image derives its config by
      # stripping the SCHEMA_REGISTRY_ prefix, so that becomes the 'port'
      # property with a URL where an integer belongs, and configure exits 1.
      enableServiceLinks: false
      containers:
        - name: schema-registry
          image: ${CONFLUENT_REGISTRY}/cp-schema-registry:${CONFLUENT_VERSION}
          ports:
            - containerPort: ${CONFLUENT_SCHEMA_REGISTRY_PORT}
          env:
            - name: SCHEMA_REGISTRY_HOST_NAME
              value: schema-registry
            - name: SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS
              value: '${BOOTSTRAP}'
            - name: SCHEMA_REGISTRY_LISTENERS
              value: http://0.0.0.0:${CONFLUENT_SCHEMA_REGISTRY_PORT}
            - name: SCHEMA_REGISTRY_KAFKASTORE_TOPIC_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
          readinessProbe:
            httpGet:
              path: /subjects
              port: ${CONFLUENT_SCHEMA_REGISTRY_PORT}
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 30
          resources:
            requests:
              cpu: "${CONFLUENT_COMPONENT_CPU_REQUEST}"
              memory: "${CONFLUENT_COMPONENT_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_COMPONENT_CPU_LIMIT}"
              memory: "${CONFLUENT_COMPONENT_MEM_LIMIT}"
EOF
    wait_rollout deployment schema-registry
    expose_route schema-registry "${CONFLUENT_SCHEMA_REGISTRY_PORT}"
else
    echo "[INFO] Skipping Schema Registry (CONFLUENT_INSTALL_SCHEMA_REGISTRY=${CONFLUENT_INSTALL_SCHEMA_REGISTRY})."
fi

# ==============================================================================
# Kafka Connect (image ships with the Datagen source connector)
# ==============================================================================
if [[ "${CONFLUENT_INSTALL_CONNECT}" == "true" ]]; then
    apply_component connect <<EOF
apiVersion: v1
kind: Service
metadata:
  name: connect
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: connect
  ports:
    - name: http
      port: ${CONFLUENT_CONNECT_PORT}
      targetPort: ${CONFLUENT_CONNECT_PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: connect
  namespace: ${NS}
  labels:
    app: connect
    app.kubernetes.io/part-of: confluent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: connect
  template:
    metadata:
      labels:
        app: connect
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      # Service 'connect' would inject CONNECT_PORT=tcp://<ip>:8083, which the
      # image reads as its own CONNECT_* config. See schema-registry above.
      enableServiceLinks: false
      containers:
        - name: connect
          image: ${CONFLUENT_CONNECT_IMAGE}
          ports:
            - containerPort: ${CONFLUENT_CONNECT_PORT}
          env:
            - name: CONNECT_BOOTSTRAP_SERVERS
              value: '${BOOTSTRAP}'
            - name: CONNECT_REST_ADVERTISED_HOST_NAME
              value: connect
            - name: CONNECT_GROUP_ID
              value: compose-connect-group
            - name: CONNECT_CONFIG_STORAGE_TOPIC
              value: docker-connect-configs
            - name: CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: CONNECT_OFFSET_FLUSH_INTERVAL_MS
              value: '10000'
            - name: CONNECT_OFFSET_STORAGE_TOPIC
              value: docker-connect-offsets
            - name: CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: CONNECT_STATUS_STORAGE_TOPIC
              value: docker-connect-status
            - name: CONNECT_STATUS_STORAGE_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: CONNECT_KEY_CONVERTER
              value: org.apache.kafka.connect.storage.StringConverter
            - name: CONNECT_VALUE_CONVERTER
              value: io.confluent.connect.avro.AvroConverter
            - name: CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL
              value: '${SR_URL}'
            # Upstream pins the interceptor jar by filename, but the datagen
            # Connect image trails the platform (0.6.4-7.6.0 alongside CP 8.2.0),
            # so its jar is not named for CONFLUENT_VERSION. Glob instead.
            - name: CLASSPATH
              value: '/usr/share/java/monitoring-interceptors/*'
            - name: CONNECT_PRODUCER_INTERCEPTOR_CLASSES
              value: io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor
            - name: CONNECT_CONSUMER_INTERCEPTOR_CLASSES
              value: io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor
            - name: CONNECT_PLUGIN_PATH
              value: '/usr/share/java,/usr/share/confluent-hub-components'
            - name: CONNECT_LOG4J_LOGGERS
              value: org.apache.zookeeper=ERROR,org.I0Itec.zkclient=ERROR,org.reflections=ERROR
          readinessProbe:
            httpGet:
              path: /connectors
              port: ${CONFLUENT_CONNECT_PORT}
            initialDelaySeconds: 60
            periodSeconds: 10
            failureThreshold: 30
          resources:
            requests:
              cpu: "${CONFLUENT_COMPONENT_CPU_REQUEST}"
              memory: "${CONFLUENT_COMPONENT_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_COMPONENT_CPU_LIMIT}"
              memory: "${CONFLUENT_COMPONENT_MEM_LIMIT}"
EOF
    wait_rollout deployment connect
    expose_route connect "${CONFLUENT_CONNECT_PORT}"
else
    echo "[INFO] Skipping Kafka Connect (CONFLUENT_INSTALL_CONNECT=${CONFLUENT_INSTALL_CONNECT})."
fi

# ==============================================================================
# ksqlDB server
# ==============================================================================
if [[ "${CONFLUENT_INSTALL_KSQLDB}" == "true" ]]; then
    apply_component ksqldb-server <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ksqldb-server
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: ksqldb-server
  ports:
    - name: http
      port: ${CONFLUENT_KSQLDB_PORT}
      targetPort: ${CONFLUENT_KSQLDB_PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ksqldb-server
  namespace: ${NS}
  labels:
    app: ksqldb-server
    app.kubernetes.io/part-of: confluent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ksqldb-server
  template:
    metadata:
      labels:
        app: ksqldb-server
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      # No collision today (image reads KSQL_*, service injects KSQLDB_SERVER_*)
      # but injected service vars have no use here either. See schema-registry.
      enableServiceLinks: false
      containers:
        - name: ksqldb-server
          image: ${CONFLUENT_REGISTRY}/cp-ksqldb-server:${CONFLUENT_VERSION}
          ports:
            - containerPort: ${CONFLUENT_KSQLDB_PORT}
          env:
            - name: KSQL_CONFIG_DIR
              value: /etc/ksql
            - name: KSQL_BOOTSTRAP_SERVERS
              value: '${BOOTSTRAP}'
            - name: KSQL_HOST_NAME
              value: ksqldb-server
            - name: KSQL_LISTENERS
              value: http://0.0.0.0:${CONFLUENT_KSQLDB_PORT}
            - name: KSQL_CACHE_MAX_BYTES_BUFFERING
              value: '0'
            - name: KSQL_KSQL_SCHEMA_REGISTRY_URL
              value: '${SR_URL}'
            - name: KSQL_KSQL_CONNECT_URL
              value: http://connect:${CONFLUENT_CONNECT_PORT}
            - name: KSQL_KSQL_LOGGING_PROCESSING_TOPIC_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: KSQL_KSQL_LOGGING_PROCESSING_TOPIC_AUTO_CREATE
              value: 'true'
            - name: KSQL_KSQL_LOGGING_PROCESSING_STREAM_AUTO_CREATE
              value: 'true'
          readinessProbe:
            httpGet:
              path: /info
              port: ${CONFLUENT_KSQLDB_PORT}
            initialDelaySeconds: 45
            periodSeconds: 10
            failureThreshold: 30
          resources:
            requests:
              cpu: "${CONFLUENT_COMPONENT_CPU_REQUEST}"
              memory: "${CONFLUENT_COMPONENT_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_COMPONENT_CPU_LIMIT}"
              memory: "${CONFLUENT_COMPONENT_MEM_LIMIT}"
EOF
    wait_rollout deployment ksqldb-server
    expose_route ksqldb-server "${CONFLUENT_KSQLDB_PORT}"
else
    echo "[INFO] Skipping ksqlDB (CONFLUENT_INSTALL_KSQLDB=${CONFLUENT_INSTALL_KSQLDB})."
fi

# ==============================================================================
# REST Proxy
# ==============================================================================
if [[ "${CONFLUENT_INSTALL_REST_PROXY}" == "true" ]]; then
    apply_component rest-proxy <<EOF
apiVersion: v1
kind: Service
metadata:
  name: rest-proxy
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: rest-proxy
  ports:
    - name: http
      port: ${CONFLUENT_REST_PROXY_PORT}
      targetPort: ${CONFLUENT_REST_PROXY_PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rest-proxy
  namespace: ${NS}
  labels:
    app: rest-proxy
    app.kubernetes.io/part-of: confluent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rest-proxy
  template:
    metadata:
      labels:
        app: rest-proxy
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      # No collision today (image reads KAFKA_REST_*, service injects
      # REST_PROXY_*) but see schema-registry for why these are suppressed.
      enableServiceLinks: false
      containers:
        - name: rest-proxy
          image: ${CONFLUENT_REGISTRY}/cp-kafka-rest:${CONFLUENT_VERSION}
          ports:
            - containerPort: ${CONFLUENT_REST_PROXY_PORT}
          env:
            - name: KAFKA_REST_HOST_NAME
              value: rest-proxy
            - name: KAFKA_REST_BOOTSTRAP_SERVERS
              value: '${BOOTSTRAP}'
            - name: KAFKA_REST_LISTENERS
              value: http://0.0.0.0:${CONFLUENT_REST_PROXY_PORT}
            - name: KAFKA_REST_SCHEMA_REGISTRY_URL
              value: '${SR_URL}'
          readinessProbe:
            httpGet:
              path: /topics
              port: ${CONFLUENT_REST_PROXY_PORT}
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 30
          resources:
            requests:
              cpu: "${CONFLUENT_COMPONENT_CPU_REQUEST}"
              memory: "${CONFLUENT_COMPONENT_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_COMPONENT_CPU_LIMIT}"
              memory: "${CONFLUENT_COMPONENT_MEM_LIMIT}"
EOF
    wait_rollout deployment rest-proxy
    expose_route rest-proxy "${CONFLUENT_REST_PROXY_PORT}"
else
    echo "[INFO] Skipping REST Proxy (CONFLUENT_INSTALL_REST_PROXY=${CONFLUENT_INSTALL_REST_PROXY})."
fi

# ==============================================================================
# Prometheus + Alertmanager (next-gen Control Center's metrics backend)
# ------------------------------------------------------------------------------
# C3 no longer computes metrics in Kafka Streams: brokers push OTLP to
# Prometheus and C3 queries it. These are Confluent's own builds - stock
# Prometheus lacks the OTLP ingest settings and C3's recording rules.
#
# All three mount the same /mnt/config. C3 WRITES trigger_rules-generated.yml
# and alertmanager-generated.yml there when you configure alerts in the UI, so
# it cannot be a read-only ConfigMap mount: an init container copies the
# ConfigMap into an emptyDir the pods then share. The trade-off is that alert
# rules are lost when the pod restarts; a PVC would persist them, at the cost
# of pinning these pods to one node.
# ==============================================================================
if [[ "${CONFLUENT_INSTALL_CONTROL_CENTER}" == "true" ]]; then
    # --------------------------------------------------------------------------
    # Basic-auth fragments spliced into the monitoring ConfigMap.
    #
    # Prometheus and Alertmanager read basic_auth_users from a web config file
    # (bcrypt hashes). Once Alertmanager is protected, Prometheus must also
    # present credentials when it pushes alerts to it. Both fragments are empty
    # when auth is disabled, which reproduces the upstream open configuration.
    # The 4-space indent matches the ConfigMap's block-scalar body.
    # --------------------------------------------------------------------------
    if [[ "${CONFLUENT_AUTH_ENABLED}" == "true" ]]; then
        _web_config_prom="    basic_auth_users:
      ${AUTH_USER}: '${AUTH_BCRYPT}'"
        _web_config_am="    basic_auth_users:
      ${AUTH_USER}: '${AUTH_BCRYPT}'"
        _prom_alerting_auth="
          basic_auth:
            username: '${AUTH_USER}'
            password: '${AUTH_PASS}'"
        # Prometheus does not document /-/ready as exempt from basic auth, so
        # the probes authenticate rather than relying on it.
        _monitoring_probe_headers="
              httpHeaders:
                - name: Authorization
                  value: Basic $(printf '%s:%s' "${AUTH_USER}" "${AUTH_PASS}" | base64 | tr -d '\n')"
    else
        _web_config_prom="    {}"
        _web_config_am="    {}"
        _prom_alerting_auth=""
        _monitoring_probe_headers=""
    fi

    apply_component monitoring-config <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: confluent-monitoring-config
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
data:
  prometheus-generated.yml: |
    global:
      scrape_interval: 60s
      evaluation_interval: 60s
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
                - alertmanager:${CONFLUENT_ALERTMANAGER_PORT}${_prom_alerting_auth}
    rule_files:
      - 'recording_rules-generated.yml'
      - 'trigger_rules-generated.yml'
    scrape_configs:
    # Flattens OTLP resource attributes into labels C3's queries group by.
    otlp:
      promote_resource_attributes: ["host.hostname", "java.version", "kafka.broker.id", "kafka.cluster.id", "kafka.version", "type"]
    # Absorbs retries and network delay on the push path.
    storage:
      tsdb:
        out_of_order_time_window: 10m
  recording_rules-generated.yml: |
    groups:
      - name: partition_level_heavy_queries
        rules:
          - record: code:io_confluent_kafka_server_log_size_by_broker:total
            expr: sum by (kafka_broker_id, kafka_cluster_id) (io_confluent_kafka_server_log_size{topic!="__cluster_metadata"})
          - record: code:io_confluent_kafka_server_log_size_by_topic:total
            expr: sum by (topic, kafka_cluster_id) (io_confluent_kafka_server_log_size{topic!="__cluster_metadata"})
          - record: code:io_confluent_kafka_server_partition_under_min_isr_by_broker:total
            expr: sum by (kafka_broker_id, kafka_cluster_id) (io_confluent_kafka_server_partition_under_min_isr)
          - record: code:io_confluent_kafka_server_log_tier_size_by_broker:total
            expr: sum by (kafka_cluster_id, kafka_broker_id) (io_confluent_kafka_server_log_tier_size{topic!="__cluster_metadata"})
          - record: code:io_confluent_kafka_server_partition_replicas_count_by_topic:total
            expr: "sum by (kafka_cluster_id, topic) (io_confluent_kafka_server_partition_replicas_count)"
          - record: code:io_confluent_kafka_server_partition_in_sync_replicas_count_by_topic:total
            expr: "sum by (kafka_cluster_id, topic) (io_confluent_kafka_server_partition_in_sync_replicas_count)"
          - record: code:io_confluent_kafka_server_broker_topic_total_fetch_requests_rate_1_min_by_topic:total
            expr: "sum by (kafka_cluster_id, topic) (io_confluent_kafka_server_broker_topic_total_fetch_requests_rate_1_min)"
          - record: code:io_confluent_kafka_server_broker_topic_total_fetch_requests_rate_1_min_by_broker:total
            expr: "sum by (kafka_cluster_id, kafka_broker_id) (io_confluent_kafka_server_broker_topic_total_fetch_requests_rate_1_min)"
          - record: code:io_confluent_kafka_server_partition_under_replicated_by_broker:total
            expr: "sum by (kafka_cluster_id, kafka_broker_id) (io_confluent_kafka_server_partition_under_replicated)"
          - record: code:io_confluent_kafka_server_partition_observer_replicas_count_by_topic:total
            expr: "sum by (kafka_cluster_id, topic) (io_confluent_kafka_server_partition_observer_replicas_count)"
          - record: code:io_confluent_kafka_server_partition_under_replicated_by_topic:total
            expr: "sum by (kafka_cluster_id, topic) (io_confluent_kafka_server_partition_under_replicated)"
          - record: code:io_confluent_kafka_server_log_tier_size_by_cluster:total
            expr: "sum by (kafka_cluster_id) (max by (partition, topic, kafka_cluster_id) (io_confluent_kafka_server_log_tier_size))"
          - record: code:io_confluent_kafka_server_partition_count_by_topic:total
            expr: "count by (kafka_cluster_id, topic) (io_confluent_kafka_server_partition_replicas_count > 0)"
          - record: code:io_confluent_kafka_server_partition_caught_up_replicas_count_by_topic:total
            expr: "sum by (kafka_cluster_id, topic) (io_confluent_kafka_server_partition_caught_up_replicas_count)"
          - record: code:io_confluent_kafka_server_log_tier_size_by_topic:total
            expr: "sum by (kafka_cluster_id, topic) (max by (topic, partition, kafka_cluster_id) (io_confluent_kafka_server_log_tier_size))"
  trigger_rules-generated.yml: |
    groups:
      - name: c3-triggers
        rules:
  alertmanager-generated.yml: |
    global:
      resolve_timeout: 1m
      smtp_require_tls: false
    receivers:
    - name: default
    route:
      receiver: default
      routes: []
  web-config-prom.yml: |
${_web_config_prom}
  web-config-am.yml: |
${_web_config_am}
EOF

    apply_component prometheus <<EOF
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: prometheus
  ports:
    - name: http
      port: ${CONFLUENT_PROMETHEUS_PORT}
      targetPort: ${CONFLUENT_PROMETHEUS_PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: ${NS}
  labels:
    app: prometheus
    app.kubernetes.io/part-of: confluent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      enableServiceLinks: false
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      initContainers:
        # C3 rewrites the rules files at runtime, so they must live on a
        # writable volume rather than the read-only ConfigMap projection.
        - name: seed-config
          image: ${CONFLUENT_PROMETHEUS_IMAGE}
          command: ['sh', '-c', 'cp /config-src/* /mnt/config/ && chmod 0644 /mnt/config/*']
          volumeMounts:
            - name: config-src
              mountPath: /config-src
            - name: config
              mountPath: /mnt/config
      containers:
        - name: prometheus
          image: ${CONFLUENT_PROMETHEUS_IMAGE}
          ports:
            - containerPort: ${CONFLUENT_PROMETHEUS_PORT}
          env:
            - name: CONFIG_PATH
              value: /mnt/config
            - name: SHOULD_LOG_TO_FILE
              value: 'false'
            - name: LOG_FILE
              value: /dev/null
          volumeMounts:
            - name: config
              mountPath: /mnt/config
          readinessProbe:
            httpGet:
              path: /-/ready
              port: ${CONFLUENT_PROMETHEUS_PORT}${_monitoring_probe_headers}
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 30
          resources:
            requests:
              cpu: "${CONFLUENT_COMPONENT_CPU_REQUEST}"
              memory: "${CONFLUENT_COMPONENT_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_COMPONENT_CPU_LIMIT}"
              memory: "${CONFLUENT_COMPONENT_MEM_LIMIT}"
      volumes:
        - name: config-src
          configMap:
            name: confluent-monitoring-config
        - name: config
          emptyDir: {}
EOF
    wait_rollout deployment prometheus

    apply_component alertmanager <<EOF
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: alertmanager
  ports:
    - name: http
      port: ${CONFLUENT_ALERTMANAGER_PORT}
      targetPort: ${CONFLUENT_ALERTMANAGER_PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: ${NS}
  labels:
    app: alertmanager
    app.kubernetes.io/part-of: confluent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      enableServiceLinks: false
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      initContainers:
        - name: seed-config
          image: ${CONFLUENT_ALERTMANAGER_IMAGE}
          command: ['sh', '-c', 'cp /config-src/* /mnt/config/ && chmod 0644 /mnt/config/*']
          volumeMounts:
            - name: config-src
              mountPath: /config-src
            - name: config
              mountPath: /mnt/config
      containers:
        - name: alertmanager
          image: ${CONFLUENT_ALERTMANAGER_IMAGE}
          ports:
            - containerPort: ${CONFLUENT_ALERTMANAGER_PORT}
          env:
            - name: CONFIG_PATH
              value: /mnt/config
            - name: SHOULD_LOG_TO_FILE
              value: 'false'
            - name: LOG_FILE
              value: /dev/null
          volumeMounts:
            - name: config
              mountPath: /mnt/config
          readinessProbe:
            httpGet:
              path: /-/ready
              port: ${CONFLUENT_ALERTMANAGER_PORT}${_monitoring_probe_headers}
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 30
          resources:
            requests:
              cpu: "${CONFLUENT_COMPONENT_CPU_REQUEST}"
              memory: "${CONFLUENT_COMPONENT_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_COMPONENT_CPU_LIMIT}"
              memory: "${CONFLUENT_COMPONENT_MEM_LIMIT}"
      volumes:
        - name: config-src
          configMap:
            name: confluent-monitoring-config
        - name: config
          emptyDir: {}
EOF
    wait_rollout deployment alertmanager
else
    echo "[INFO] Skipping Prometheus/Alertmanager (CONFLUENT_INSTALL_CONTROL_CENTER=${CONFLUENT_INSTALL_CONTROL_CENTER})."
fi

# ==============================================================================
# Control Center
# ==============================================================================
if [[ "${CONFLUENT_INSTALL_CONTROL_CENTER}" == "true" ]]; then
    # --------------------------------------------------------------------------
    # Control Center auth.
    #
    # Two separate concerns:
    #   1. C3's own UI login - Jetty BASIC auth against a JAAS property file.
    #      PropertyFileLoginModule reads plaintext "user: password,role", so the
    #      password (not the bcrypt hash) goes here; the file arrives via a
    #      projected secret, never in the ConfigMap.
    #   2. C3 calling Prometheus/Alertmanager, which are now protected - the
    #      *.basic.auth.user.info properties carry "user:password".
    # --------------------------------------------------------------------------
    if [[ "${CONFLUENT_AUTH_ENABLED}" == "true" ]]; then
        _c3_auth_env="
            - name: CONTROL_CENTER_REST_AUTHENTICATION_METHOD
              value: 'BASIC'
            - name: CONTROL_CENTER_REST_AUTHENTICATION_REALM
              value: 'c3'
            - name: CONTROL_CENTER_REST_AUTHENTICATION_ROLES
              value: 'Administrators'
            - name: CONTROL_CENTER_AUTH_RESTRICTED_ROLES
              value: 'Restricted'
            - name: CONTROL_CENTER_PROMETHEUS_BASIC_AUTH_USER_INFO
              value: '${AUTH_USER}:${AUTH_PASS}'
            - name: CONTROL_CENTER_ALERTMANAGER_BASIC_AUTH_USER_INFO
              value: '${AUTH_USER}:${AUTH_PASS}'
            - name: CONTROL_CENTER_OPTS
              value: '-Djava.security.auth.login.config=/mnt/auth/c3.jaas'"
        _c3_auth_mount="
            - name: auth
              mountPath: /mnt/auth
              readOnly: true"
        _c3_auth_volume="
        - name: auth
          secret:
            secretName: ${CONFLUENT_AUTH_SECRET}-c3
            defaultMode: 0400"
        # The readiness probe must authenticate too, or C3 never goes Ready.
        _c3_probe_headers="
              httpHeaders:
                - name: Authorization
                  value: Basic $(printf '%s:%s' "${AUTH_USER}" "${AUTH_PASS}" | base64 | tr -d '\n')"

        # The JAAS module resolves 'file=' at login time, so both files live in
        # one secret mounted at /mnt/auth.
        oc create secret generic "${CONFLUENT_AUTH_SECRET}-c3" \
            --from-literal=c3.jaas="c3 {
    org.eclipse.jetty.security.jaas.spi.PropertyFileLoginModule required
    file=\"/mnt/auth/c3-users.properties\";
};" \
            --from-literal=c3-users.properties="${AUTH_USER}: ${AUTH_PASS},Administrators" \
            -n "${NS}" --dry-run=client -o yaml | oc apply -f - >/dev/null
        echo "[INFO] Control Center JAAS credentials written to secret '${CONFLUENT_AUTH_SECRET}-c3'."
    else
        _c3_auth_env=""
        _c3_auth_mount=""
        _c3_auth_volume=""
        _c3_probe_headers=""
    fi

    apply_component control-center <<EOF
apiVersion: v1
kind: Service
metadata:
  name: control-center
  namespace: ${NS}
  labels:
    app.kubernetes.io/part-of: confluent
spec:
  selector:
    app: control-center
  ports:
    - name: http
      port: ${CONFLUENT_CONTROL_CENTER_PORT}
      targetPort: ${CONFLUENT_CONTROL_CENTER_PORT}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: control-center
  namespace: ${NS}
  labels:
    app: control-center
    app.kubernetes.io/part-of: confluent
spec:
  replicas: 1
  selector:
    matchLabels:
      app: control-center
  template:
    metadata:
      labels:
        app: control-center
        app.kubernetes.io/part-of: confluent
    spec:
      serviceAccountName: ${SA}
      # Service 'control-center' would inject CONTROL_CENTER_PORT=tcp://<ip>:9021,
      # colliding with the image's own CONTROL_CENTER_* config. Note this pod
      # sets PORT deliberately; the injected vars are what must be suppressed.
      enableServiceLinks: false
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
      initContainers:
        # C3 writes the trigger and alertmanager rule files as you configure
        # alerts, so they are seeded onto a writable volume, not mounted
        # read-only from the ConfigMap.
        - name: seed-config
          image: ${CONFLUENT_CONTROL_CENTER_IMAGE}
          command: ['sh', '-c', 'cp /config-src/* /mnt/config/ && chmod 0644 /mnt/config/*']
          volumeMounts:
            - name: config-src
              mountPath: /config-src
            - name: config
              mountPath: /mnt/config
      containers:
        - name: control-center
          image: ${CONFLUENT_CONTROL_CENTER_IMAGE}
          ports:
            - containerPort: ${CONFLUENT_CONTROL_CENTER_PORT}
          env:
            - name: CONTROL_CENTER_BOOTSTRAP_SERVERS
              value: '${BOOTSTRAP}'
            - name: CONTROL_CENTER_CONNECT_CONNECT-DEFAULT_CLUSTER
              value: 'connect:${CONFLUENT_CONNECT_PORT}'
            - name: CONTROL_CENTER_CONNECT_HEALTHCHECK_ENDPOINT
              value: '/connectors'
            - name: CONTROL_CENTER_KSQL_KSQLDB1_URL
              value: http://ksqldb-server:${CONFLUENT_KSQLDB_PORT}
            - name: CONTROL_CENTER_KSQL_KSQLDB1_ADVERTISED_URL
              value: http://ksqldb-server:${CONFLUENT_KSQLDB_PORT}
            - name: CONTROL_CENTER_SCHEMA_REGISTRY_URL
              value: '${SR_URL}'
            - name: CONTROL_CENTER_REPLICATION_FACTOR
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            - name: CONTROL_CENTER_INTERNAL_TOPICS_PARTITIONS
              value: '${CONFLUENT_PARTITIONS}'
            - name: CONTROL_CENTER_MONITORING_INTERCEPTOR_TOPIC_PARTITIONS
              value: '${CONFLUENT_PARTITIONS}'
            - name: CONFLUENT_METRICS_TOPIC_REPLICATION
              value: '${CONFLUENT_REPLICATION_FACTOR}'
            # --- next-gen C3: metrics come from Prometheus, not Kafka Streams ---
            - name: CONTROL_CENTER_PROMETHEUS_ENABLE
              value: 'true'
            - name: CONTROL_CENTER_PROMETHEUS_URL
              value: '${PROM_URL}'
            - name: CONTROL_CENTER_PROMETHEUS_RULES_FILE
              value: /mnt/config/trigger_rules-generated.yml
            - name: CONTROL_CENTER_ALERTMANAGER_URL
              value: '${ALERTMANAGER_URL}'
            - name: CONTROL_CENTER_ALERTMANAGER_CONFIG_FILE
              value: /mnt/config/alertmanager-generated.yml
            - name: PORT
              value: '${CONFLUENT_CONTROL_CENTER_PORT}'${_c3_auth_env}
          volumeMounts:
            - name: config
              mountPath: /mnt/config${_c3_auth_mount}
          readinessProbe:
            httpGet:
              path: /
              port: ${CONFLUENT_CONTROL_CENTER_PORT}${_c3_probe_headers}
            initialDelaySeconds: 90
            periodSeconds: 10
            failureThreshold: 40
          resources:
            requests:
              cpu: "${CONFLUENT_COMPONENT_CPU_REQUEST}"
              memory: "${CONFLUENT_COMPONENT_MEM_REQUEST}"
            limits:
              cpu: "${CONFLUENT_COMPONENT_CPU_LIMIT}"
              memory: "${CONFLUENT_COMPONENT_MEM_LIMIT}"
      volumes:
        - name: config-src
          configMap:
            name: confluent-monitoring-config
        - name: config
          emptyDir: {}${_c3_auth_volume}
EOF
    wait_rollout deployment control-center
    expose_route control-center "${CONFLUENT_CONTROL_CENTER_PORT}"
else
    echo "[INFO] Skipping Control Center (CONFLUENT_INSTALL_CONTROL_CENTER=${CONFLUENT_INSTALL_CONTROL_CENTER})."
fi

# ==============================================================================
# Summary
# ==============================================================================
echo ""
echo "[INFO] Confluent Platform ${CONFLUENT_VERSION} installed in project '${NS}'."
echo "[INFO] In-cluster bootstrap servers: ${BOOTSTRAP}"

if [[ "${CONFLUENT_AUTH_ENABLED}" == "true" ]]; then
    echo "[INFO] Web UIs require basic auth - user '${AUTH_USER}', password:"
    echo "[INFO]   oc get secret ${CONFLUENT_AUTH_SECRET} -n ${NS} -o jsonpath='{.data.password}' | base64 --decode"
else
    echo "[WARN] Web UIs are exposed WITHOUT authentication (CONFLUENT_AUTH_ENABLED=false)."
fi

if [[ "${CONFLUENT_CREATE_ROUTES}" == "true" ]]; then
    echo "[INFO] Routes:"
    oc get routes -n "${NS}" -l app.kubernetes.io/part-of=confluent \
        -o custom-columns='NAME:.metadata.name,URL:.spec.host' --no-headers \
        | while read -r _name _host; do echo "         ${_name}: https://${_host}"; done
fi
