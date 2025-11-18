#!/usr/bin/env bash

# Setup a local MIT Kerberos KDC for testing
# This script creates an ephemeral, isolated Kerberos environment

set -euo pipefail

# Check for required Kerberos tools
if ! command -v kdb5_util &> /dev/null; then
    echo "error: kdb5_util not found. Please install Kerberos server packages."
    exit 1
fi

if ! command -v krb5kdc &> /dev/null; then
    echo "error: krb5kdc not found. Please install Kerberos server packages."
    exit 1
fi

if ! command -v kadmin.local &> /dev/null; then
    echo "error: kadmin.local not found. Please install Kerberos admin packages."
    exit 1
fi

# Environment setup
export TEST_DIR="${1:-}"
if [[ -z "${TEST_DIR}" ]]; then
    echo "error: TEST_DIR not provided"
    exit 1
fi

export REALM="${2:-}"
if [[ -z "${REALM}" ]]; then
    echo "error: REALM not provided"
    exit 1
fi

export KDC_PORT="${3:-}"
if [[ -z "${KDC_PORT}" ]]; then
    echo "error: KDC_PORT not provided"
    exit 1
fi

export KRB5_CONFIG="${TEST_DIR}/krb5.conf"
export KRB5_KDC_PROFILE="${TEST_DIR}/kdc.conf"

echo "Setting up KDC in ${TEST_DIR}"
echo "Realm: ${REALM}"
echo "KDC Port: ${KDC_PORT}"

# Create krb5.conf
cat > "${KRB5_CONFIG}" << EOF
[libdefaults]
    default_realm = ${REALM}
    dns_lookup_realm = false
    dns_lookup_kdc = false
    ticket_lifetime = 24h
    renew_lifetime = 7d
    forwardable = true
    rdns = false
    default_ccache_name = FILE:${TEST_DIR}/krb5cc

[realms]
    ${REALM} = {
        kdc = localhost:${KDC_PORT}
        admin_server = localhost:${KDC_PORT}
        default_domain = localhost
    }

[domain_realm]
    .localhost = ${REALM}
    localhost = ${REALM}
EOF

# Create kdc.conf
cat > "${KRB5_KDC_PROFILE}" << EOF
[kdcdefaults]
    kdc_ports = ${KDC_PORT}
    kdc_tcp_ports = ${KDC_PORT}

[realms]
    ${REALM} = {
        database_name = ${TEST_DIR}/principal
        admin_keytab = FILE:${TEST_DIR}/kadm5.keytab
        acl_file = ${TEST_DIR}/kadm5.acl
        key_stash_file = ${TEST_DIR}/.k5.${REALM}
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = aes256-cts
        supported_enctypes = aes256-cts:normal aes128-cts:normal
        default_principal_flags = +preauth
    }
EOF

# Create ACL file for kadmin
echo "*/admin@${REALM} *" > "${TEST_DIR}/kadm5.acl"

# Initialize KDC database
echo "Initializing KDC database..."
kdb5_util create -s -P masterpassword -r "${REALM}" -d "${TEST_DIR}/principal" 2>&1 | grep -v "^Loading" || true

# Start KDC
echo "Starting KDC..."
krb5kdc -n &
KDC_PID=$!
echo "${KDC_PID}" > "${TEST_DIR}/kdc.pid"

# Wait for KDC to be ready
sleep 2

# Verify KDC is running
if ! ps -p "${KDC_PID}" > /dev/null 2>&1; then
    echo "error: KDC failed to start"
    exit 1
fi

echo "KDC started successfully (PID: ${KDC_PID})"

# Create principals
echo "Creating principals..."
kadmin.local -r "${REALM}" -q "addprinc -randkey HTTP/localhost@${REALM}" 2>&1 | grep -v "^Authenticating" || true
kadmin.local -r "${REALM}" -q "addprinc -pw clientpassword testclient@${REALM}" 2>&1 | grep -v "^Authenticating" || true

# Export keytabs
echo "Exporting keytabs..."
kadmin.local -r "${REALM}" -q "ktadd -k ${TEST_DIR}/http.keytab HTTP/localhost@${REALM}" 2>&1 | grep -v "^Authenticating" || true
kadmin.local -r "${REALM}" -q "ktadd -k ${TEST_DIR}/client.keytab testclient@${REALM}" 2>&1 | grep -v "^Authenticating" || true

# Set proper permissions
chmod 600 "${TEST_DIR}"/*.keytab

echo "KDC setup complete!"
echo "KRB5_CONFIG=${KRB5_CONFIG}"
echo "Service keytab: ${TEST_DIR}/http.keytab"
echo "Client keytab: ${TEST_DIR}/client.keytab"
