#!/usr/bin/env bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Validate required environment variables
if [[ -z "${PIA_USER}" ]]; then
    error "PIA_USER environment variable is required"
    exit 1
fi

if [[ -z "${PIA_PASS}" ]]; then
    error "PIA_PASS environment variable is required"
    exit 1
fi

# Set defaults
export PORT_FORWARD_REFRESH_INTERVAL="${PORT_FORWARD_REFRESH_INTERVAL:-900}"
export PORT_FILE="${PORT_FILE:-/config/pia-port.txt}"
export PORT_DATA_FILE="${PORT_DATA_FILE:-/config/pia-port-data.json}"

log "==================================="
log "PIA Port Forwarding Manager"
log "==================================="
log ""
log "This container manages PIA port forwarding"
log "It assumes you are already connected to a PIA VPN"
log ""
log "Refresh interval: ${PORT_FORWARD_REFRESH_INTERVAL} seconds"

if [[ -n "${QBITTORRENT_HOST}" ]]; then
    log "qBittorrent integration: ENABLED"
    log "  Host: ${QBITTORRENT_HOST}"
    log "  User: ${QBITTORRENT_USER:-admin}"
else
    log "qBittorrent integration: DISABLED"
fi

log "==================================="
log ""

# Check if we can reach the internet (basic VPN check)
log "Checking internet connectivity..."
if ! curl -s --max-time 5 https://api.ipify.org &>/dev/null; then
    error "Cannot reach the internet. Are you connected to the VPN?"
    error "This container must be on a network that routes through PIA VPN"
    exit 1
fi

# Get external IP to confirm VPN
EXTERNAL_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "unknown")
log "External IP: ${EXTERNAL_IP}"
log ""

# Start port forwarding loop
log "Starting port forwarding loop..."
exec /usr/local/bin/port-forward-loop.sh
