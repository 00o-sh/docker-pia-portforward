#!/usr/bin/env bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[PIA-PF]${NC} $*"
}

error() {
    echo -e "${RED}[PIA-PF ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[PIA-PF WARN]${NC} $*"
}

info() {
    echo -e "${BLUE}[PIA-PF INFO]${NC} $*"
}

# Configuration
PORT_FILE="${PORT_FILE:-/config/pia-port.txt}"
PORT_DATA_FILE="${PORT_DATA_FILE:-/config/pia-port-data.json}"
REFRESH_INTERVAL="${PORT_FORWARD_REFRESH_INTERVAL:-900}" # 15 minutes default

# qBittorrent settings
QBITTORRENT_HOST="${QBITTORRENT_HOST:-}"
QBITTORRENT_USER="${QBITTORRENT_USER:-admin}"
QBITTORRENT_PASS="${QBITTORRENT_PASS:-}"

# Cookie file for qBittorrent session
QB_COOKIE_FILE="/tmp/qbittorrent-cookies.txt"

# PIA API endpoints
PIA_TOKEN=""
PIA_GATEWAY="${PIA_GATEWAY:-}"  # Can be set via environment variable

# Function to get PIA auth token
get_pia_token() {
    log "Getting PIA authentication token..."

    local response
    response=$(curl -s -u "${PIA_USER}:${PIA_PASS}" \
        "https://www.privateinternetaccess.com/api/client/v2/token" 2>/dev/null)

    if [[ -z "${response}" ]]; then
        error "Failed to get authentication token from PIA"
        return 1
    fi

    local token
    token=$(echo "${response}" | jq -r '.token' 2>/dev/null)

    if [[ -z "${token}" || "${token}" == "null" ]]; then
        error "Invalid token response from PIA"
        return 1
    fi

    PIA_TOKEN="${token}"
    log "Authentication successful"
    return 0
}

# Function to detect PIA gateway
detect_gateway() {
    # If gateway already set via environment, use it
    if [[ -n "${PIA_GATEWAY}" ]]; then
        log "Using configured gateway: ${PIA_GATEWAY}"
        return 0
    fi

    log "Detecting PIA gateway from routing table..."

    # Show routing table for debugging
    info "Current routes:"
    ip route | while read line; do
        info "  ${line}"
    done

    # Try to get gateway from default route
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}' | head -1)

    if [[ -z "${gateway}" ]]; then
        error "Could not detect gateway IP from default route"
        error "You may need to set PIA_GATEWAY environment variable manually"
        return 1
    fi

    PIA_GATEWAY="${gateway}"
    log "Gateway detected: ${PIA_GATEWAY}"
    return 0
}

# Function to get port forward from PIA
get_port_forward() {
    if [[ -z "${PIA_TOKEN}" ]]; then
        error "No PIA token available"
        return 1
    fi

    if [[ -z "${PIA_GATEWAY}" ]]; then
        error "No gateway detected"
        return 1
    fi

    log "Requesting port forward from PIA..."

    local response
    response=$(curl -s -m 5 -G \
        --data-urlencode "token=${PIA_TOKEN}" \
        "http://${PIA_GATEWAY}:19999/getSignature" 2>/dev/null)

    if [[ -z "${response}" ]]; then
        error "No response from port forward API"
        return 1
    fi

    # Check if response contains an error
    if echo "${response}" | jq -e '.status' &>/dev/null; then
        local status
        status=$(echo "${response}" | jq -r '.status')
        if [[ "${status}" == "ERROR" ]]; then
            local message
            message=$(echo "${response}" | jq -r '.message // "Unknown error"')
            error "Port forward request failed: ${message}"
            return 1
        fi
    fi

    # Extract port, payload, and signature
    local port payload signature
    port=$(echo "${response}" | jq -r '.port' 2>/dev/null)
    payload=$(echo "${response}" | jq -r '.payload' 2>/dev/null)
    signature=$(echo "${response}" | jq -r '.signature' 2>/dev/null)

    if [[ -z "${port}" || "${port}" == "null" ]]; then
        error "Failed to get port from response"
        return 1
    fi

    # Save payload and signature for refresh
    echo "${payload}" > /tmp/pia-payload.txt
    echo "${signature}" > /tmp/pia-signature.txt

    echo "${port}"
    return 0
}

# Function to bind/refresh port forward
bind_port() {
    local port=$1

    if [[ -z "${PIA_GATEWAY}" ]]; then
        error "No gateway detected"
        return 1
    fi

    if [[ ! -f /tmp/pia-payload.txt ]] || [[ ! -f /tmp/pia-signature.txt ]]; then
        error "Missing payload or signature files"
        return 1
    fi

    local payload signature
    payload=$(cat /tmp/pia-payload.txt)
    signature=$(cat /tmp/pia-signature.txt)

    log "Binding port ${port} to gateway..."

    local response
    response=$(curl -s -m 5 -G \
        --data-urlencode "payload=${payload}" \
        --data-urlencode "signature=${signature}" \
        "http://${PIA_GATEWAY}:19999/bindPort" 2>/dev/null)

    if [[ -z "${response}" ]]; then
        warn "No response from bind port API"
        return 1
    fi

    # Check for success
    if echo "${response}" | jq -e '.status' &>/dev/null; then
        local status
        status=$(echo "${response}" | jq -r '.status')
        if [[ "${status}" == "OK" ]]; then
            log "Port ${port} bound successfully"
            return 0
        else
            local message
            message=$(echo "${response}" | jq -r '.message // "Unknown error"')
            warn "Port bind returned status ${status}: ${message}"
            return 1
        fi
    fi

    # If no status field, assume success
    log "Port binding completed"
    return 0
}

# Function to authenticate with qBittorrent
qb_login() {
    if [[ -z "${QBITTORRENT_HOST}" ]]; then
        return 1
    fi

    log "Authenticating with qBittorrent at ${QBITTORRENT_HOST}..."

    local response
    response=$(curl -s -i -c "${QB_COOKIE_FILE}" \
        --data-urlencode "username=${QBITTORRENT_USER}" \
        --data-urlencode "password=${QBITTORRENT_PASS}" \
        "${QBITTORRENT_HOST}/api/v2/auth/login" 2>/dev/null)

    if echo "${response}" | grep -q "Ok."; then
        log "qBittorrent authentication successful"
        return 0
    else
        error "qBittorrent authentication failed"
        return 1
    fi
}

# Function to update qBittorrent port
qb_set_port() {
    local port=$1

    if [[ -z "${QBITTORRENT_HOST}" ]]; then
        return 0
    fi

    log "Updating qBittorrent listening port to ${port}..."

    # Try to login first
    if ! qb_login; then
        error "Cannot update qBittorrent: authentication failed"
        return 1
    fi

    # Update preferences
    local response
    response=$(curl -s -b "${QB_COOKIE_FILE}" \
        --data-urlencode "json={\"listen_port\":${port}}" \
        "${QBITTORRENT_HOST}/api/v2/app/setPreferences" 2>/dev/null)

    if [[ $? -eq 0 ]]; then
        log "qBittorrent port updated successfully to ${port}"
        return 0
    else
        error "Failed to update qBittorrent port"
        return 1
    fi
}

# Function to save port information
save_port_info() {
    local port=$1
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Save simple port file
    mkdir -p "$(dirname "${PORT_FILE}")"
    echo "${port}" > "${PORT_FILE}"

    # Save detailed port data
    cat > "${PORT_DATA_FILE}" <<EOF
{
  "port": ${port},
  "timestamp": "${timestamp}",
  "next_refresh": "$(date -u -d "+${REFRESH_INTERVAL} seconds" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    info "Port ${port} saved to ${PORT_FILE}"
}

# Main loop
main() {
    log "Starting PIA port forwarding manager"
    log "Refresh interval: ${REFRESH_INTERVAL} seconds"

    if [[ -n "${QBITTORRENT_HOST}" ]]; then
        log "qBittorrent integration enabled: ${QBITTORRENT_HOST}"
    else
        log "Running in standalone mode (no qBittorrent integration)"
    fi

    # Get authentication token
    if ! get_pia_token; then
        error "Failed to authenticate with PIA"
        exit 1
    fi

    # Detect gateway
    if ! detect_gateway; then
        error "Failed to detect PIA gateway"
        exit 1
    fi

    # Initial port forward
    log "Getting initial port forward..."
    local current_port
    if ! current_port=$(get_port_forward); then
        error "Failed to get initial port forward"
        exit 1
    fi

    log "Port forwarding enabled on port: ${current_port}"

    # Bind the port
    if ! bind_port "${current_port}"; then
        warn "Failed to bind port, but continuing..."
    fi

    # Save port information
    save_port_info "${current_port}"

    # Update qBittorrent if configured
    if [[ -n "${QBITTORRENT_HOST}" ]]; then
        qb_set_port "${current_port}"
    fi

    # Main refresh loop
    while true; do
        log "Sleeping for ${REFRESH_INTERVAL} seconds before refresh..."
        sleep "${REFRESH_INTERVAL}"

        log "=== Port Forward Refresh Cycle ==="

        # Refresh the port binding
        if bind_port "${current_port}"; then
            info "Port ${current_port} refresh successful"

            # Update timestamp
            save_port_info "${current_port}"
        else
            warn "Port refresh failed, attempting to get new port forward..."

            # Try to get a new token and port forward
            if get_pia_token && current_port=$(get_port_forward); then
                log "New port obtained: ${current_port}"

                # Bind the new port
                bind_port "${current_port}"

                # Save new port
                save_port_info "${current_port}"

                # Update qBittorrent
                if [[ -n "${QBITTORRENT_HOST}" ]]; then
                    qb_set_port "${current_port}"
                fi
            else
                error "Failed to refresh port forward, will retry next cycle"
            fi
        fi

        log "==================================="
    done
}

# Run main loop
main
