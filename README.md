# PIA Port Forwarding Manager

Lightweight Docker container for managing PIA (Private Internet Access) port forwarding with automatic refresh and qBittorrent integration.

**Note:** This container does NOT establish a VPN connection. It assumes you already have containers running through a PIA VPN (e.g., using gluetun, another VPN container, or network routing). This container only handles the port forwarding API and refresh cycle.

## Features

- Automatic port forwarding from PIA
- Auto-refresh every 15 minutes (configurable) to keep port alive
- qBittorrent Web API integration - automatically updates listening port
- Exposes port to file for use by other containers
- Lightweight Alpine-based image
- No VPN overhead - works with existing VPN setup

## How It Works

1. Container detects the PIA gateway from your existing VPN connection
2. Authenticates with PIA and requests port forward
3. Saves forwarded port to `/config/pia-port.txt`
4. Optionally updates qBittorrent with the new port
5. Refreshes port binding every 15 minutes to maintain the assignment

## Prerequisites

- You must already have a VPN connection to PIA (via gluetun, another container, or network routing)
- The container must be on a network that routes through the PIA VPN
- For qBittorrent integration: qBittorrent Web UI must be accessible

## Environment Variables

### Required

- `PIA_USER` - Your PIA username (format: p#######)
- `PIA_PASS` - Your PIA password

### Optional

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
docker build -t pia-portforward:latest .
```

## Running

### Standalone (Port File Only)

```bash
docker run --rm -it \
  --network=container:gluetun \
  -v ./config:/config \
  -e PIA_USER=p1234567 \
  -e PIA_PASS=your_password \
  pia-portforward:latest
```

The forwarded port will be written to `./config/pia-port.txt` and automatically refreshed every 15 minutes.

### With qBittorrent Integration

```bash
docker run --rm -it \
  --network=container:gluetun \
  -v ./config:/config \
  -e PIA_USER=p1234567 \
  -e PIA_PASS=your_password \
  -e QBITTORRENT_HOST=http://localhost:8080 \
  -e QBITTORRENT_USER=admin \
  -e QBITTORRENT_PASS=adminpass \
  pia-portforward:latest
```

This will automatically update qBittorrent's listening port when the forwarded port is obtained or refreshed.

## Docker Compose Example

### With Gluetun VPN Container

```yaml
services:
  gluetun:
    image: qmcgaw/gluetun
    cap_add:
      - NET_ADMIN
    environment:
      - VPN_SERVICE_PROVIDER=private internet access
      - OPENVPN_USER=p1234567
      - OPENVPN_PASSWORD=your_password
      - SERVER_REGIONS=US New York
    volumes:
      - ./gluetun:/gluetun

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent
    network_mode: "service:gluetun"
    environment:
      - WEBUI_PORT=8080
    volumes:
      - ./qbittorrent:/config
      - ./downloads:/downloads

  pia-portforward:
    image: pia-portforward:latest
    network_mode: "service:gluetun"
    depends_on:
      - gluetun
      - qbittorrent
    environment:
      - PIA_USER=p1234567
      - PIA_PASS=your_password
      - QBITTORRENT_HOST=http://localhost:8080
      - QBITTORRENT_USER=admin
      - QBITTORRENT_PASS=adminpass
    volumes:
      - ./pia-config:/config
```

### Sharing Port with Other Containers

```yaml
services:
  # ... gluetun setup ...

  pia-portforward:
    image: pia-portforward:latest
    network_mode: "service:gluetun"
    environment:
      - PIA_USER=p1234567
      - PIA_PASS=your_password
    volumes:
      - pia-data:/config

  some-app:
    image: some-app
    volumes:
      - pia-data:/pia:ro
    # App can read port from /pia/pia-port.txt

volumes:
  pia-data:
```

## Port Files

### `/config/pia-port.txt`

Simple text file containing just the port number:
```
54321
```

### `/config/pia-port-data.json`

Detailed JSON with port and timing information:
```json
{
  "port": 54321,
  "timestamp": "2026-01-14T19:30:00Z",
  "next_refresh": "2026-01-14T19:45:00Z"
}
```

## Troubleshooting

### "Cannot reach the internet"

This means the container isn't on a network that routes through the VPN. Make sure you're using `network_mode: "service:gluetun"` or similar.

### "Could not detect gateway IP"

The container couldn't find the VPN gateway. Ensure your VPN connection is established before starting this container.

### "Port forward request failed"

- Ensure your PIA credentials are correct
- Verify your VPN server supports port forwarding (not all PIA servers do)
- Check that you're connected to a PIA server (not another VPN provider)

### qBittorrent authentication failed

- Verify `QBITTORRENT_HOST` is correct and accessible from this container
- Check that qBittorrent Web UI credentials match
- Ensure qBittorrent Web UI is enabled

## How PIA Port Forwarding Works

1. **Authentication**: Get token from PIA API using credentials
2. **Request Port**: Call gateway's `getSignature` endpoint to get port assignment
3. **Bind Port**: Call gateway's `bindPort` endpoint to activate the port
4. **Refresh**: Re-bind every 15 minutes to keep port active (PIA requirement)

The port assignment lasts up to 2 months, but must be refreshed regularly to remain active.

## Comparison with Other Solutions

**vs Full VPN Container**: This is much lighter - no VPN overhead, just port forwarding management

**vs Manual Scripts**: Automatic refresh, qBittorrent integration, containerized

**vs Gluetun Built-in**: Works with any VPN setup, not just Gluetun; direct qBittorrent integration

## Source

Port forwarding implementation based on [PIA's manual-connections](https://github.com/pia-foss/manual-connections) API documentation.
