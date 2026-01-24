#!/usr/bin/env bash
# Health check script for PIA port forwarding container
# Returns 0 if healthy, 1 if unhealthy

set -e

# Configuration
PORT_FILE="${PORT_FILE:-/config/pia-port.txt}"
PORT_DATA_FILE="${PORT_DATA_FILE:-/config/pia-port-data.json}"
MAX_AGE_SECONDS="${HEALTHCHECK_MAX_AGE:-1800}"  # 30 minutes default

# Check if port forwarding loop process is running
if ! pgrep -f "port-forward-loop.sh" > /dev/null 2>&1; then
    echo "UNHEALTHY: port-forward-loop.sh is not running"
    exit 1
fi

# Check if port file exists
if [[ ! -f "${PORT_FILE}" ]]; then
    echo "UNHEALTHY: Port file does not exist at ${PORT_FILE}"
    exit 1
fi

# Check if port file is recent
if [[ -f "${PORT_FILE}" ]]; then
    file_age=$(($(date +%s) - $(stat -c %Y "${PORT_FILE}" 2>/dev/null || stat -f %m "${PORT_FILE}" 2>/dev/null || echo 0)))
    if [[ ${file_age} -gt ${MAX_AGE_SECONDS} ]]; then
        echo "UNHEALTHY: Port file is too old (${file_age}s > ${MAX_AGE_SECONDS}s)"
        exit 1
    fi
fi

# Validate port file content
if [[ -f "${PORT_FILE}" ]]; then
    port=$(cat "${PORT_FILE}" 2>/dev/null || echo "")
    if [[ ! "${port}" =~ ^[0-9]+$ ]] || [[ ${port} -lt 1024 ]] || [[ ${port} -gt 65535 ]]; then
        echo "UNHEALTHY: Invalid port number in ${PORT_FILE}: ${port}"
        exit 1
    fi
fi

# Check if we can reach PIA gateway (if configured)
if [[ -n "${PIA_GATEWAY}" ]]; then
    if ! timeout 3 curl -s "http://${PIA_GATEWAY}:19999/" > /dev/null 2>&1; then
        echo "UNHEALTHY: Cannot reach PIA gateway at ${PIA_GATEWAY}:19999"
        exit 1
    fi
fi

# All checks passed
echo "OK"
exit 0
