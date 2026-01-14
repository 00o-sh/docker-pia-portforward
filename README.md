# PIA VPN Docker Image

Docker image for connecting to Private Internet Access (PIA) VPN using their manual connection scripts.

## Features

- Supports both WireGuard and OpenVPN protocols
- Auto-selects best region based on latency
- Optional port forwarding
- Automatic reconnection on failure
- Health monitoring

## Environment Variables

### Required

- `PIA_USER` - Your PIA username (format: p#######)
- `PIA_PASS` - Your PIA password

### Optional

- `VPN_PROTOCOL` - Protocol to use (default: `wireguard`)
  - `wireguard`
  - `openvpn_udp_standard`
  - `openvpn_udp_strong`
  - `openvpn_tcp_standard`
  - `openvpn_tcp_strong`
- `PREFERRED_REGION` - Specific region to connect to (default: auto-select)
- `MAX_LATENCY` - Maximum acceptable server latency in seconds (default: `0.05`)
- `PIA_PF` - Enable port forwarding (default: `false`)
- `PIA_DNS` - Use PIA DNS servers (default: `true`)
- `DISABLE_IPV6` - Disable IPv6 (default: `yes`)

### Port Forwarding Options

When `PIA_PF=true`, the following additional options are available:

- `PORT_FORWARD_REFRESH_INTERVAL` - Seconds between port refresh (default: `900` = 15 minutes)
- `PORT_FILE` - Location to save forwarded port number (default: `/config/pia-port.txt`)
- `PORT_DATA_FILE` - Location to save detailed port data JSON (default: `/config/pia-port-data.json`)

### qBittorrent Integration

Automatically update qBittorrent's listening port when port forwarding is enabled:

- `QBITTORRENT_HOST` - qBittorrent Web UI URL (e.g., `http://qbittorrent:8080`)
- `QBITTORRENT_USER` - Web UI username (default: `admin`)
- `QBITTORRENT_PASS` - Web UI password

## Building

```bash
docker build -t pia-vpn:latest .
```

## Running

### Basic Usage (No Port Forwarding)

```bash
docker run --rm -it \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  -e PIA_USER=p1234567 \
  -e PIA_PASS=your_password \
  -e VPN_PROTOCOL=wireguard \
  pia-vpn:latest
```

### With Port Forwarding (Standalone)

```bash
docker run --rm -it \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  -v ./config:/config \
  -e PIA_USER=p1234567 \
  -e PIA_PASS=your_password \
  -e VPN_PROTOCOL=wireguard \
  -e PIA_PF=true \
  pia-vpn:latest
```

The forwarded port will be written to `/config/pia-port.txt` and automatically refreshed every 15 minutes.

### With qBittorrent Integration

```bash
docker run --rm -it \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  -v ./config:/config \
  -e PIA_USER=p1234567 \
  -e PIA_PASS=your_password \
  -e VPN_PROTOCOL=wireguard \
  -e PIA_PF=true \
  -e QBITTORRENT_HOST=http://qbittorrent:8080 \
  -e QBITTORRENT_USER=admin \
  -e QBITTORRENT_PASS=adminpass \
  pia-vpn:latest
```

This will automatically update qBittorrent's listening port when the forwarded port is obtained or refreshed.

## Port Forwarding Details

When `PIA_PF=true`:

1. **Initial Setup**: Gets a forwarded port from PIA and saves it to `/config/pia-port.txt`
2. **Auto-Refresh**: Refreshes the port binding every 15 minutes (configurable via `PORT_FORWARD_REFRESH_INTERVAL`)
3. **qBittorrent Sync**: If `QBITTORRENT_HOST` is set, automatically updates qBittorrent's listening port
4. **Persistence**: Port information is saved to a volume for easy access by other containers

### Sharing Port with Other Containers

The forwarded port is written to `/config/pia-port.txt`. You can share this with other containers:

```bash
# In docker-compose.yml
services:
  pia-vpn:
    volumes:
      - pia-config:/config
    environment:
      - PIA_PF=true

  qbittorrent:
    volumes:
      - pia-config:/pia-config:ro
    # Read port from /pia-config/pia-port.txt
```

## Kubernetes Deployment

See `/kubernetes/apps/network/pia-vpn/` for Kubernetes manifests that integrate with:
- Multus for network attachment
- External-secrets for credential management
- 1Password for secret storage

## Source

Based on [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections)
