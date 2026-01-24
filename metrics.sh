#!/usr/bin/env bash
# Prometheus metrics exporter for PIA port forwarding container

set -e

# Configuration
PORT_FILE="${PORT_FILE:-/config/pia-port.txt}"
PORT_DATA_FILE="${PORT_DATA_FILE:-/config/pia-port-data.json}"
METRICS_FILE="${METRICS_FILE:-/tmp/pia-metrics.txt}"

# Helper function to output Prometheus metric
metric() {
    local name=$1
    local type=$2
    local help=$3
    local value=$4
    local labels=$5

    echo "# HELP ${name} ${help}"
    echo "# TYPE ${name} ${type}"
    if [[ -n "${labels}" ]]; then
        echo "${name}{${labels}} ${value}"
    else
        echo "${name} ${value}"
    fi
}

# Start output
echo "# PIA Port Forwarding Metrics"
echo ""

# Current forwarded port
if [[ -f "${PORT_FILE}" ]]; then
    current_port=$(cat "${PORT_FILE}" 2>/dev/null || echo "0")
    if [[ "${current_port}" =~ ^[0-9]+$ ]]; then
        metric "pia_forwarded_port" "gauge" "Currently forwarded port number" "${current_port}"
        echo ""
    fi
fi

# Port file age (seconds since last update)
if [[ -f "${PORT_FILE}" ]]; then
    file_mtime=$(stat -c %Y "${PORT_FILE}" 2>/dev/null || stat -f %m "${PORT_FILE}" 2>/dev/null || echo 0)
    current_time=$(date +%s)
    age=$((current_time - file_mtime))
    metric "pia_port_file_age_seconds" "gauge" "Seconds since port file was last updated" "${age}"
    echo ""
fi

# Last update timestamp
if [[ -f "${PORT_DATA_FILE}" ]] && command -v jq &>/dev/null; then
    timestamp=$(jq -r '.timestamp // empty' "${PORT_DATA_FILE}" 2>/dev/null || echo "")
    if [[ -n "${timestamp}" ]]; then
        # Convert ISO 8601 to Unix timestamp
        unix_timestamp=$(date -d "${timestamp}" +%s 2>/dev/null || echo "0")
        if [[ ${unix_timestamp} -gt 0 ]]; then
            metric "pia_last_update_timestamp_seconds" "gauge" "Unix timestamp of last successful port update" "${unix_timestamp}"
            echo ""
        fi
    fi
fi

# Process status - is port forwarding loop running?
if pgrep -f "port-forward-loop.sh" > /dev/null 2>&1; then
    metric "pia_process_running" "gauge" "Whether the port forwarding loop process is running (1=running, 0=stopped)" "1"
else
    metric "pia_process_running" "gauge" "Whether the port forwarding loop process is running (1=running, 0=stopped)" "0"
fi
echo ""

# Read metrics from metrics file if it exists
if [[ -f "${METRICS_FILE}" ]]; then
    # Refresh success count
    if grep -q "^pia_refresh_success_total" "${METRICS_FILE}" 2>/dev/null; then
        success_count=$(grep "^pia_refresh_success_total" "${METRICS_FILE}" | awk '{print $2}' || echo "0")
        metric "pia_refresh_success_total" "counter" "Total number of successful port refresh operations" "${success_count}"
        echo ""
    fi

    # Refresh failure count
    if grep -q "^pia_refresh_failure_total" "${METRICS_FILE}" 2>/dev/null; then
        failure_count=$(grep "^pia_refresh_failure_total" "${METRICS_FILE}" | awk '{print $2}' || echo "0")
        metric "pia_refresh_failure_total" "counter" "Total number of failed port refresh operations" "${failure_count}"
        echo ""
    fi

    # Port changes count
    if grep -q "^pia_port_changes_total" "${METRICS_FILE}" 2>/dev/null; then
        changes_count=$(grep "^pia_port_changes_total" "${METRICS_FILE}" | awk '{print $2}' || echo "0")
        metric "pia_port_changes_total" "counter" "Total number of times the forwarded port has changed" "${changes_count}"
        echo ""
    fi

    # qBittorrent update success
    if grep -q "^pia_qbittorrent_update_success_total" "${METRICS_FILE}" 2>/dev/null; then
        qb_success=$(grep "^pia_qbittorrent_update_success_total" "${METRICS_FILE}" | awk '{print $2}' || echo "0")
        metric "pia_qbittorrent_update_success_total" "counter" "Total number of successful qBittorrent port updates" "${qb_success}"
        echo ""
    fi

    # qBittorrent update failure
    if grep -q "^pia_qbittorrent_update_failure_total" "${METRICS_FILE}" 2>/dev/null; then
        qb_failure=$(grep "^pia_qbittorrent_update_failure_total" "${METRICS_FILE}" | awk '{print $2}' || echo "0")
        metric "pia_qbittorrent_update_failure_total" "counter" "Total number of failed qBittorrent port updates" "${qb_failure}"
        echo ""
    fi
fi

# qBittorrent integration status
if [[ -n "${QBITTORRENT_HOST}" ]]; then
    metric "pia_qbittorrent_integration_enabled" "gauge" "Whether qBittorrent integration is enabled (1=enabled, 0=disabled)" "1"
else
    metric "pia_qbittorrent_integration_enabled" "gauge" "Whether qBittorrent integration is enabled (1=enabled, 0=disabled)" "0"
fi
echo ""

# Container uptime
if [[ -f /proc/1/stat ]]; then
    boot_time=$(awk '{print $22}' /proc/1/stat)
    clock_ticks=$(getconf CLK_TCK)
    current_time=$(date +%s)
    uptime=$((current_time - boot_time / clock_ticks))
    metric "pia_container_uptime_seconds" "gauge" "Container uptime in seconds" "${uptime}"
    echo ""
fi
