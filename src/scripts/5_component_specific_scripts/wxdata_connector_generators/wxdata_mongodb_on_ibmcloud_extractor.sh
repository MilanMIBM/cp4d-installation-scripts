#!/bin/zsh
# Make this script executable if it isn't already, then re-run it
if [ ! -x "$0" ]; then chmod +x "$0" && exec "$0" "$@"; fi

set -euo pipefail

SECONDS=0
trap '(( SECONDS >= 60 )) && echo "[TIMER] $(basename $0) completed in $((SECONDS/60))m $((SECONDS%60))s" || echo "[TIMER] $(basename $0) completed in ${SECONDS}s"' EXIT

# -----------------------------------------------------------------------------
# Extracts the inputs watsonx.data needs to add a "Databases for MongoDB on IBM
# Cloud" component (Add component -> MongoDB -> Create new connection) from the
# service credential JSON that IBM Cloud issues for the deployment.
#
# For each field on the watsonx.data form this maps:
#   Authentication database name -> .connection.mongodb.query_options.authSource
#   Hostname / Port (one per row) -> .connection.mongodb.hosts[]
#   Username                      -> .connection.mongodb.authentication.username
#   Password                      -> .connection.mongodb.authentication.password
#   Port is SSL enabled           -> .connection.mongodb.query_options.tls
#   Upload certificate            -> .connection.mongodb.certificate.certificate_base64
#                                    (base64-decoded to <certificate_name>.pem)
#
# Outputs (written to ./mongodb_parsed_conn_credentials, created if absent, in
# the directory the script is run from):
#   <display>_connection.json  - the sorted connection inputs
#   <certificate_name>.pem      - the decoded, unencoded TLS CA certificate
#
# Usage:
#   ./wxdata_mongodb_on_ibmcloud_extractor.sh <credential.json> [output_dir]
#
# Requires: jq
# -----------------------------------------------------------------------------

if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but was not found on PATH." >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") <credential.json> [output_dir]" >&2
    exit 1
fi

SRC_FILE="$1"
if [[ ! -f "${SRC_FILE}" ]]; then
    echo "Error: input file '${SRC_FILE}' not found." >&2
    exit 1
fi

if ! jq empty "${SRC_FILE}" >/dev/null 2>&1; then
    echo "Error: input file '${SRC_FILE}' is not valid JSON." >&2
    exit 1
fi

# Output folder: default to ./mongodb_parsed_conn_credentials relative to the
# current working directory (where the script was invoked from), overridable.
OUT_DIR="${2:-$(pwd)/mongodb_parsed_conn_credentials}"
mkdir -p "${OUT_DIR}"

# Confirm the MongoDB connection block exists before parsing.
if [[ "$(jq -r 'has("connection") and (.connection | has("mongodb"))' "${SRC_FILE}")" != "true" ]]; then
    echo "Error: '${SRC_FILE}' does not contain a .connection.mongodb block." >&2
    exit 1
fi

# --- Certificate: decode the base64 CA into an unencoded <name>.pem ----------
CERT_NAME="$(jq -r '.connection.mongodb.certificate.name // empty' "${SRC_FILE}")"
CERT_B64="$(jq -r '.connection.mongodb.certificate.certificate_base64 // empty' "${SRC_FILE}")"

CERT_FILE=""
if [[ -n "${CERT_B64}" ]]; then
    # Fall back to a stable name if the credential omitted the certificate name.
    [[ -n "${CERT_NAME}" ]] || CERT_NAME="mongodb_ca"
    CERT_FILE="${CERT_NAME}.pem"
    if ! printf '%s' "${CERT_B64}" | base64 -d > "${OUT_DIR}/${CERT_FILE}" 2>/dev/null; then
        echo "Error: failed to base64-decode the certificate." >&2
        exit 1
    fi
    echo "Wrote certificate: ${OUT_DIR}/${CERT_FILE}"
else
    echo "Warning: no certificate found in credential; skipping .pem output." >&2
fi

# --- Connection inputs: emit the watsonx.data form fields, neatly sorted -----
# Sorted keys (jq -S) so the output is stable and easy to diff/read. The hosts
# array preserves order (each row on the form). The certificate is referenced by
# the .pem filename we just wrote rather than re-embedding the base64 blob.
DISPLAY_NAME="Databases for MongoDB on IBM Cloud"
CONN_FILE="mongodb_on_ibmcloud_connection.json"

jq -S \
    --arg display_name "${DISPLAY_NAME}" \
    --arg certificate_file "${CERT_FILE}" \
    '
    .connection.mongodb as $m
    | {
        display_name: $display_name,
        authentication_database: ($m.query_options.authSource // "admin"),
        hosts: [ $m.hosts[] | { hostname: .hostname, port: .port } ],
        username: $m.authentication.username,
        password: $m.authentication.password,
        ssl_enabled: ($m.query_options.tls // false),
        certificate_name: ($m.certificate.name // null),
        certificate_file: (if $certificate_file == "" then null else $certificate_file end),
        database: ($m.database // null),
        replica_set: ($m.replica_set // $m.query_options.replicaSet // null)
      }
    ' "${SRC_FILE}" > "${OUT_DIR}/${CONN_FILE}"

echo "Wrote connection inputs: ${OUT_DIR}/${CONN_FILE}"
echo "Done. Parsed credentials are in: ${OUT_DIR}"
