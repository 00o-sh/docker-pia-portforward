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

# Function to get current forwarded port
get_forwarded_port() {
    cd /opt/pia

    # Run port forwarding script
    if ! ./port_forwarding.sh 2>&1 | tee /tmp/pf-output.txt; then
        error "Port forwarding script failed"
        return 1
    fi

    # Extract port from output
    local port
    port=$(grep -oP 'port \K[0-9]+' /tmp/pf-output.txt | head -1)

    if [[ -z "${port}" ]]; then
        # Try to read from file created by port_forwarding.sh
        if [[ -f /opt/pia/port.dat ]]; then
            port=$(cat /opt/pia/port.dat)
        fi
    fi

    if [[ -z "${port}" ]]; then
        error "Could not determine forwarded port"
        return 1
    fi

    echo "${port}"
    return 0
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
  "expires_at": "$(date -u -d "+2 months" +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF

    info "Port ${port} saved to ${PORT_FILE}"
}

# Function to refresh port binding
refresh_port_binding() {
    cd /opt/pia

    log "Refreshing port binding..."

    # The port_forwarding.sh script handles the refresh
    if ./port_forwarding.sh &>/dev/null; then
        log "Port binding refreshed successfully"
        return 0
    else
        warn "Port binding refresh may have failed"
        return 1
    fi
}

# Main loop
main() {
    log "Starting PIA port forwarding loop"
    log "Refresh interval: ${REFRESH_INTERVAL} seconds"

    if [[ -n "${QBITTORRENT_HOST}" ]]; then
        log "qBittorrent integration enabled: ${QBITTORRENT_HOST}"
    else
        log "Running in standalone mode (no qBittorrent integration)"
    fi

    # Initial port forward
    log "Getting initial port forward..."
    local current_port
    if ! current_port=$(get_forwarded_port); then
        error "Failed to get initial port forward"
        exit 1
    fi

    log "Port forwarding enabled on port: ${current_port}"

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
        if refresh_port_binding; then
            # Get the port again to confirm
            local new_port
            if new_port=$(get_forwarded_port); then
                if [[ "${new_port}" != "${current_port}" ]]; then
                    log "Port changed from ${current_port} to ${new_port}"
                    current_port="${new_port}"

                    # Save new port
                    save_port_info "${current_port}"

                    # Update qBittorrent
                    if [[ -n "${QBITTORRENT_HOST}" ]]; then
                        qb_set_port "${current_port}"
                    fi
                else
                    info "Port unchanged: ${current_port}"
                fi
            else
                warn "Could not verify port after refresh"
            fi
        else
            error "Port refresh failed, will retry next cycle"
        fi

        log "==================================="
    done
}

# Run main loop
main
