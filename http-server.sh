#!/usr/bin/env bash
# Simple HTTP server for health and metrics endpoints
# Uses socat for better compatibility

set -e

# Configuration
HTTP_PORT="${HTTP_PORT:-9090}"
HEALTHZ_SCRIPT="/usr/local/bin/healthz.sh"
METRICS_SCRIPT="/usr/local/bin/metrics.sh"

# Color output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[HTTP-SERVER]${NC} $*"
}

info() {
    echo -e "${BLUE}[HTTP-SERVER INFO]${NC} $*"
}

# HTTP response helper
http_response() {
    local status=$1
    local content_type=$2
    local body=$3

    printf "HTTP/1.1 %s\r\n" "${status}"
    printf "Content-Type: %s\r\n" "${content_type}"
    printf "Content-Length: %d\r\n" "${#body}"
    printf "Connection: close\r\n"
    printf "\r\n"
    printf "%s" "${body}"
}

# Handle HTTP request
handle_request() {
    local request_line
    read -r request_line

    # Parse request
    local method path
    method=$(echo "${request_line}" | awk '{print $1}')
    path=$(echo "${request_line}" | awk '{print $2}')

    # Read and discard headers
    while read -r line; do
        line=$(echo "$line" | tr -d '\r\n')
        [[ -z "$line" ]] && break
    done

    info "Request: ${method} ${path}"

    case "${path}" in
        /healthz|/health|/healthcheck)
            if [[ -x "${HEALTHZ_SCRIPT}" ]]; then
                if output=$("${HEALTHZ_SCRIPT}" 2>&1); then
                    http_response "200 OK" "text/plain; charset=utf-8" "${output}"
                else
                    http_response "503 Service Unavailable" "text/plain; charset=utf-8" "${output}"
                fi
            else
                http_response "500 Internal Server Error" "text/plain; charset=utf-8" "Health check script not found"
            fi
            ;;

        /metrics)
            if [[ -x "${METRICS_SCRIPT}" ]]; then
                if output=$("${METRICS_SCRIPT}" 2>&1); then
                    http_response "200 OK" "text/plain; version=0.0.4; charset=utf-8" "${output}"
                else
                    http_response "500 Internal Server Error" "text/plain; charset=utf-8" "Failed to generate metrics"
                fi
            else
                http_response "500 Internal Server Error" "text/plain; charset=utf-8" "Metrics script not found"
            fi
            ;;

        /|/index.html)
            local body="PIA Port Forwarding Manager

Available endpoints:
- GET /healthz - Health check endpoint
- GET /metrics - Prometheus metrics
- GET / - This page
"
            http_response "200 OK" "text/plain; charset=utf-8" "${body}"
            ;;

        *)
            http_response "404 Not Found" "text/plain; charset=utf-8" "Not Found"
            ;;
    esac
}

# Main server loop using socat
start_server() {
    log "Starting HTTP server on port ${HTTP_PORT}"
    log "Endpoints available:"
    log "  - http://localhost:${HTTP_PORT}/healthz"
    log "  - http://localhost:${HTTP_PORT}/metrics"

    # Export functions for subshells
    export -f handle_request
    export -f http_response
    export -f info
    export -f log
    export HEALTHZ_SCRIPT
    export METRICS_SCRIPT
    export GREEN BLUE NC

    # Use socat for reliable HTTP serving
    socat -T 60 TCP-LISTEN:${HTTP_PORT},fork,reuseaddr EXEC:"/bin/bash -c handle_request"
}

# If script is executed (not sourced), start server
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    start_server
fi
