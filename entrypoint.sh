#!/usr/bin/env bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[PIA-VPN]${NC} $*"
}

error() {
    echo -e "${RED}[PIA-VPN ERROR]${NC} $*" >&2
}

warn() {
    echo -e "${YELLOW}[PIA-VPN WARN]${NC} $*"
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
export VPN_PROTOCOL="${VPN_PROTOCOL:-wireguard}"
export PREFERRED_REGION="${PREFERRED_REGION:-}"
export MAX_LATENCY="${MAX_LATENCY:-0.05}"
export PIA_PF="${PIA_PF:-false}"
export PIA_DNS="${PIA_DNS:-true}"
export DISABLE_IPV6="${DISABLE_IPV6:-yes}"
export AUTOCONNECT="${AUTOCONNECT:-true}"

log "Starting PIA VPN connection..."
log "Protocol: ${VPN_PROTOCOL}"
log "Preferred Region: ${PREFERRED_REGION:-auto}"
log "Port Forwarding: ${PIA_PF}"

# Change to PIA directory
cd /opt/pia

# Get authentication token
log "Authenticating..."
if ! PIA_TOKEN=$(./get_token.sh); then
    error "Failed to get authentication token"
    exit 1
fi
export PIA_TOKEN
log "Authentication successful"

# Select region
log "Selecting region..."
if [[ -n "${PREFERRED_REGION}" ]]; then
    # Use preferred region if specified
    ./get_region.sh
else
    # Auto-select best region based on latency
    ./get_region.sh
fi

# Check if region selection was successful
if [[ ! -f /opt/pia/vpninfo.json ]]; then
    error "Failed to select VPN region"
    exit 1
fi

# Connect based on protocol
log "Establishing VPN connection..."
case "${VPN_PROTOCOL}" in
    wireguard)
        if ! ./connect_to_wireguard_with_token.sh; then
            error "Failed to connect via WireGuard"
            exit 1
        fi
        ;;
    openvpn_udp_standard|openvpn_udp_strong|openvpn_tcp_standard|openvpn_tcp_strong)
        if ! ./connect_to_openvpn_with_token.sh; then
            error "Failed to connect via OpenVPN"
            exit 1
        fi
        ;;
    *)
        error "Unknown VPN protocol: ${VPN_PROTOCOL}"
        error "Valid options: wireguard, openvpn_udp_standard, openvpn_udp_strong, openvpn_tcp_standard, openvpn_tcp_strong"
        exit 1
        ;;
esac

log "VPN connection established successfully!"

# Enable port forwarding if requested
if [[ "${PIA_PF}" == "true" ]]; then
    log "Enabling port forwarding with auto-refresh..."
    # Run port forward loop in background
    /usr/local/bin/port-forward-loop.sh &
    PF_PID=$!
    log "Port forwarding loop started (PID: ${PF_PID})"

    # Give it a moment to get initial port
    sleep 5

    # Check if port file was created
    if [[ -f /config/pia-port.txt ]]; then
        PF_PORT=$(cat /config/pia-port.txt)
        log "Port forwarding enabled on port: ${PF_PORT}"
    else
        warn "Port forwarding may not have initialized yet"
    fi
fi

# Show connection info
log "=== VPN Connection Info ==="
if [[ -f /opt/pia/vpninfo.json ]]; then
    REGION=$(jq -r '.region' /opt/pia/vpninfo.json)
    SERVER=$(jq -r '.server' /opt/pia/vpninfo.json)
    log "Region: ${REGION}"
    log "Server: ${SERVER}"
fi

# Get external IP
if command -v curl &> /dev/null; then
    EXTERNAL_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "unknown")
    log "External IP: ${EXTERNAL_IP}"
fi

log "==========================="

# Health check loop
log "Monitoring VPN connection..."
while true; do
    sleep 60

    # Check if VPN interface exists
    if [[ "${VPN_PROTOCOL}" == "wireguard" ]]; then
        if ! wg show &>/dev/null; then
            error "WireGuard interface is down! Reconnecting..."
            exec "$0" "$@"
        fi
    fi

    # Simple connectivity check
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        warn "Network connectivity check failed"
    fi
done
