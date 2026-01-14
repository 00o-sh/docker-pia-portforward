# PIA Port Forwarding Manager

Lightweight Docker container for managing PIA (Private Internet Access) port forwarding with automatic refresh and qBittorrent integration.

**Note:** This container does NOT establish a VPN connection. It assumes you already have containers running through a PIA VPN. This works with:
- Container networking (gluetun, etc.)
- Kubernetes with Multus/CNI plugins
- Router-level VPN where entire VLANs are routed through PIA

The container only handles the port forwarding API and refresh cycle.

## Features

- Automatic port forwarding from PIA
- Auto-refresh every 15 minutes (configurable) to keep port alive
- qBittorrent Web API integration - automatically updates listening port
- Exposes port to file for use by other containers
- Lightweight Alpine-based image
- No VPN overhead - works with existing VPN setup
- Runs as non-root user (UID 1000) for security
- OCI-compliant with proper labels

## How It Works

1. Container intelligently detects the PIA gateway by:
   - Testing the default gateway (works with gluetun/container networking)
   - Probing common PIA internal IPs (10.x.0.1 addresses)
   - Testing endpoints found in the routing table
   - Verifying each candidate responds on port 19999 (PIA API port)
2. Authenticates with PIA and requests port forward
3. Saves forwarded port to `/config/pia-port.txt`
4. Optionally updates qBittorrent with the new port
5. Refreshes port binding every 15 minutes to maintain the assignment

**No configuration needed** - gateway detection works automatically with gluetun, router-level VPN, and most other setups.

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
- `PIA_GATEWAY` - Manually specify PIA gateway IP (default: auto-detect via intelligent probing - rarely needed)

### qBittorrent Integration

Automatically update qBittorrent's listening port when port forwarding is enabled:

- `QBITTORRENT_HOST` - qBittorrent Web UI URL (e.g., `http://qbittorrent:8080`)
- `QBITTORRENT_USER` - Web UI username (default: `admin`)
- `QBITTORRENT_PASS` - Web UI password

## Installation

### Helm Chart (Recommended for Kubernetes)

The easiest way to deploy on Kubernetes is using the Helm chart:

```bash
# Install from OCI registry
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password

# With qBittorrent integration
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password \
  --set qbittorrent.enabled=true \
  --set qbittorrent.host=http://qbittorrent:8080 \
  --set qbittorrent.password=adminpass
```

See [chart/README.md](chart/README.md) for full documentation.

### Building Container Image

```bash
docker build -t pia-portforward:latest .
```

## Security

This container runs as a non-root user (UID/GID 1000) for security. Ensure mounted volumes have appropriate permissions:

```bash
# For Docker
mkdir -p ./config
chown 1000:1000 ./config

# For Kubernetes - PVC permissions are handled automatically
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

## Kubernetes Deployment

**Recommended:** Use the [Helm chart](chart/README.md) for easy installation:
```bash
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password \
  --set multus.enabled=true \
  --set multus.networkName=pia-vlan-network
```

### Manual Deployment with Multus and Router-Level VPN

If you prefer to deploy manually, here's an example for router-level PIA VPN with Multus:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pia-portforward-config
  namespace: media
data:
  PIA_USER: "p1234567"
  PORT_FORWARD_REFRESH_INTERVAL: "900"
  QBITTORRENT_HOST: "http://qbittorrent:8080"
  QBITTORRENT_USER: "admin"
---
apiVersion: v1
kind: Secret
metadata:
  name: pia-portforward-secrets
  namespace: media
type: Opaque
stringData:
  PIA_PASS: "your_password"
  QBITTORRENT_PASS: "adminpass"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pia-portforward
  namespace: media
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pia-portforward
  template:
    metadata:
      labels:
        app: pia-portforward
      annotations:
        k8s.v1.cni.cncf.io/networks: pia-vlan-network
    spec:
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
      containers:
      - name: pia-portforward
        image: pia-portforward:latest
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: false
          runAsNonRoot: true
        envFrom:
        - configMapRef:
            name: pia-portforward-config
        - secretRef:
            name: pia-portforward-secrets
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: pia-portforward-config
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pia-portforward-config
  namespace: media
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
```

### Multus NetworkAttachmentDefinition Example

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: pia-vlan-network
  namespace: media
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "eth1",
      "mode": "bridge",
      "ipam": {
        "type": "dhcp"
      }
    }
```

This assumes `eth1` is connected to a VLAN that routes through your PIA VPN at the router level.

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

The container tests multiple gateway candidates automatically. If detection fails, check the logs - it will show which candidates were tested.

**Common causes:**
- VPN not connected yet (wait for VPN to establish first)
- Non-standard PIA gateway IP
- Firewall blocking port 19999

The error message will show all tested IPs. If you see your PIA gateway in the list but it's not responding, check:
1. Is the VPN actually connected? (`curl https://api.ipify.org` should show a PIA IP)
2. Is port 19999 accessible? (`curl -v http://<gateway>:19999/`)

**Manual override (rarely needed):**
```yaml
env:
  - name: PIA_GATEWAY
    value: "10.x.x.1"  # Your PIA gateway IP
```

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
