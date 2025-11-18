#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Enable verbose output for debugging
set -x

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR=""
KDC_PID=""
ASPNET_SERVER_PID=""

# Cleanup function
cleanup() {
    local exit_code=$?
    set +e

    echo "Cleaning up..."

    # Kill server
    if [[ -n "${ASPNET_SERVER_PID}" ]] && ps -p "${ASPNET_SERVER_PID}" > /dev/null 2>&1; then
        echo "Stopping ASP.NET Core server (PID: ${ASPNET_SERVER_PID})"
        kill "${ASPNET_SERVER_PID}" 2>/dev/null || true
        sleep 1
        kill -9 "${ASPNET_SERVER_PID}" 2>/dev/null || true
    fi

    # Kill KDC
    if [[ -n "${KDC_PID}" ]] && ps -p "${KDC_PID}" > /dev/null 2>&1; then
        echo "Stopping KDC (PID: ${KDC_PID})"
        kill "${KDC_PID}" 2>/dev/null || true
        sleep 1
        kill -9 "${KDC_PID}" 2>/dev/null || true
    elif [[ -n "${TEST_DIR}" ]] && [[ -f "${TEST_DIR}/kdc.pid" ]]; then
        KDC_PID=$(cat "${TEST_DIR}/kdc.pid")
        if ps -p "${KDC_PID}" > /dev/null 2>&1; then
            echo "Stopping KDC from pidfile (PID: ${KDC_PID})"
            kill "${KDC_PID}" 2>/dev/null || true
            sleep 1
            kill -9 "${KDC_PID}" 2>/dev/null || true
        fi
    fi

    # Clean up temp directory
    if [[ -n "${TEST_DIR}" ]] && [[ -d "${TEST_DIR}" ]]; then
        echo "Removing temporary directory: ${TEST_DIR}"
        rm -rf "${TEST_DIR}"
    fi

    if [[ ${exit_code} -ne 0 ]]; then
        echo "Test FAILED with exit code ${exit_code}"
    fi

    exit ${exit_code}
}

trap cleanup EXIT INT TERM

# Generate random values for isolation
RANDOM_ID="${RANDOM}${RANDOM}"
REALM="TEST${RANDOM_ID}.LOCAL"
KDC_PORT=$((10000 + (RANDOM % 20000)))
ASPNET_PORT=$((30000 + (RANDOM % 20000)))

# Ensure ports are different
while [[ ${ASPNET_PORT} -eq ${KDC_PORT} ]]; do
    ASPNET_PORT=$((30000 + (RANDOM % 20000)))
done

echo "=========================================="
echo "Kerberos Authentication Test"
echo "=========================================="
echo "Realm: ${REALM}"
echo "KDC Port: ${KDC_PORT}"
echo "ASP.NET Core Port: ${ASPNET_PORT}"
echo "=========================================="

# Create temporary directory
TEST_DIR=$(mktemp -d -t kerberos-test-XXXXXX)
echo "Test directory: ${TEST_DIR}"

# Setup KDC
echo ""
echo "Setting up Kerberos KDC..."
export KRB5_CONFIG="${TEST_DIR}/krb5.conf"
export KRB5_KDC_PROFILE="${TEST_DIR}/kdc.conf"
export KRB5CCNAME="FILE:${TEST_DIR}/krb5cc"

bash "${SCRIPT_DIR}/setup-kdc.sh" "${TEST_DIR}" "${REALM}" "${KDC_PORT}"

# Read KDC PID
if [[ -f "${TEST_DIR}/kdc.pid" ]]; then
    KDC_PID=$(cat "${TEST_DIR}/kdc.pid")
    echo "KDC running with PID: ${KDC_PID}"
fi

# Acquire client credentials
echo ""
echo "Acquiring client Kerberos credentials..."
export KRB5_KTNAME="${TEST_DIR}/client.keytab"
kinit -kt "${KRB5_KTNAME}" "testclient@${REALM}"

# Verify ticket
echo ""
echo "Verifying Kerberos ticket..."
klist

echo ""
echo "=========================================="
echo "ASP.NET Core with Kerberos"
echo "=========================================="

# Build client
echo "Building client..."
pushd "${SCRIPT_DIR}/client"
dotnet build -c Release
popd

# Build ASP.NET Core server
echo "Building ASP.NET Core server..."
pushd "${SCRIPT_DIR}/aspnet-server"
dotnet build -c Release
popd

# Start ASP.NET Core server
echo "Starting ASP.NET Core server on port ${ASPNET_PORT}..."
export KRB5_KTNAME="${TEST_DIR}/http.keytab"
export SERVER_PORT="${ASPNET_PORT}"

dotnet "${SCRIPT_DIR}"/aspnet-server/bin/Release/*/aspnet-server.dll &
ASPNET_SERVER_PID=$!
echo "ASP.NET Core server started (PID: ${ASPNET_SERVER_PID})"

# Wait for server to be ready
../run-until-success-with-backoff curl "http://localhost:${ASPNET_PORT}/" --negotiate -u : || {
    echo "FAIL: ASP.NET Core server did not start properly"
    exit 1
}

# Run client test
echo "Running client test..."
export KRB5_KTNAME="${TEST_DIR}/client.keytab"
export SERVER_URL="http://localhost:${ASPNET_PORT}/"

if dotnet "${SCRIPT_DIR}"/client/bin/Release/*/client.dll; then
    echo ""
    echo "======================================"
    echo "ASP.NET Core Test: PASS"
    echo "======================================"
else
    echo ""
    echo "======================================"
    echo "ASP.NET Core Test: FAIL"
    echo "======================================"
    exit 1
fi

# Stop ASP.NET Core server
echo "Stopping ASP.NET Core server..."
kill "${ASPNET_SERVER_PID}" 2>/dev/null || true
sleep 1
kill -9 "${ASPNET_SERVER_PID}" 2>/dev/null || true
ASPNET_SERVER_PID=""

echo ""
echo "=========================================="
echo "Kerberos Authentication Test: PASS"
echo "=========================================="

exit 0
