# PIA Port Forwarding Manager Helm Chart

This Helm chart deploys the PIA Port Forwarding Manager on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+ (for OCI registry support)
- PIA VPN connection (via gluetun, Multus, or router-level VPN)
- PIA account with port forwarding enabled

## Installation

### From OCI Registry

```bash
# Add the repository (optional, Helm 3.8+ can install directly)
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password
```

### From Local Chart

```bash
# Clone the repository
git clone https://github.com/00o-sh/docker-pia-portforward.git
cd docker-pia-portforward

# Install the chart
helm install pia-portforward ./chart \
  --set pia.user=p1234567 \
  --set pia.password=your_password
```

## Configuration

### Required Values

| Parameter | Description |
|-----------|-------------|
| `pia.user` | Your PIA username (format: p1234567) |
| `pia.password` | Your PIA password |

### Common Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Container image repository | `ghcr.io/00o-sh/pia-portforward` |
| `image.tag` | Container image tag | Chart appVersion |
| `pia.refreshInterval` | Port refresh interval in seconds | `900` (15 min) |
| `pia.gateway` | Manual PIA gateway IP (optional) | Auto-detect |
| `qbittorrent.enabled` | Enable qBittorrent integration | `false` |
| `qbittorrent.host` | qBittorrent Web UI URL | `http://qbittorrent:8080` |
| `qbittorrent.user` | qBittorrent Web UI username | `admin` |
| `qbittorrent.password` | qBittorrent Web UI password | `""` |
| `multus.enabled` | Enable Multus networking | `false` |
| `multus.networkName` | Multus NetworkAttachmentDefinition name | `pia-vlan-network` |
| `persistence.enabled` | Enable persistent storage | `true` |
| `persistence.size` | PVC size | `1Mi` |
| `resources.requests.memory` | Memory request | `64Mi` |
| `resources.requests.cpu` | CPU request | `50m` |
| `metrics.enabled` | Enable metrics service | `true` |
| `metrics.serviceMonitor.enabled` | Create Prometheus ServiceMonitor | `false` |
| `livenessProbe.initialDelaySeconds` | Liveness probe initial delay | `30` |
| `readinessProbe.initialDelaySeconds` | Readiness probe initial delay | `10` |

See [values.yaml](./values.yaml) for all available options.

## Examples

### Basic Installation (Standalone)

```bash
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password
```

### With qBittorrent Integration

```bash
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password \
  --set qbittorrent.enabled=true \
  --set qbittorrent.host=http://qbittorrent:8080 \
  --set qbittorrent.password=adminpass
```

### With Multus (Router-Level VPN)

```bash
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password \
  --set multus.enabled=true \
  --set multus.networkName=pia-vlan-network
```

### Using values.yaml File

Create a `values.yaml`:

```yaml
pia:
  user: "p1234567"
  password: "your_password"
  refreshInterval: 900

qbittorrent:
  enabled: true
  host: "http://qbittorrent:8080"
  user: "admin"
  password: "adminpass"

multus:
  enabled: true
  networkName: "pia-vlan-network"

persistence:
  enabled: true
  size: 1Mi

resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "200m"
```

Install:

```bash
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  -f values.yaml
```

## Upgrading

```bash
# Upgrade to latest version
helm upgrade pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward

# Upgrade with new values
helm upgrade pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.refreshInterval=600
```

## Uninstalling

```bash
helm uninstall pia-portforward
```

## Accessing the Forwarded Port

The forwarded port is saved to `/config/pia-port.txt`. You can share the PVC with other containers to access the port:

```yaml
# In another deployment
volumeMounts:
- name: pia-config
  mountPath: /pia-config
  readOnly: true

volumes:
- name: pia-config
  persistentVolumeClaim:
    claimName: pia-portforward
```

Then read the port:

```bash
port=$(cat /pia-config/pia-port.txt)
```

## Monitoring & Observability

The chart includes built-in monitoring capabilities with health checks and Prometheus metrics.

### Health Checks

The deployment includes liveness and readiness probes that monitor the container's health:

```bash
# Check pod health status
kubectl get pods -l app.kubernetes.io/name=pia-portforward

# View health check details
kubectl describe pod -l app.kubernetes.io/name=pia-portforward | grep -A 10 "Liveness\|Readiness"
```

The health endpoint (`/healthz`) verifies:
- Port forwarding loop is running
- Port file exists and is recent
- Port number is valid
- PIA gateway is reachable

### Prometheus Metrics

The container exposes Prometheus metrics on port 9090 at `/metrics`.

**Enable metrics service:**

```yaml
metrics:
  enabled: true
  service:
    type: ClusterIP
    port: 9090
```

**Available metrics:**
- `pia_forwarded_port` - Current forwarded port
- `pia_refresh_success_total` - Successful refreshes
- `pia_refresh_failure_total` - Failed refreshes
- `pia_port_changes_total` - Port change count
- `pia_qbittorrent_update_success_total` - qBittorrent update successes
- `pia_qbittorrent_update_failure_total` - qBittorrent update failures
- And more...

### Prometheus Operator Integration

For clusters with Prometheus Operator, enable ServiceMonitor:

```bash
helm install pia-portforward oci://ghcr.io/00o-sh/charts/pia-portforward \
  --set pia.user=p1234567 \
  --set pia.password=your_password \
  --set metrics.enabled=true \
  --set metrics.serviceMonitor.enabled=true \
  --set metrics.serviceMonitor.labels.release=prometheus
```

Or in values.yaml:

```yaml
metrics:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    labels:
      release: prometheus  # Match your Prometheus Operator label selector
```

### Manual Metrics Access

Port-forward to access metrics locally:

```bash
# Port forward the service
kubectl port-forward svc/pia-portforward 9090:9090

# View metrics
curl http://localhost:9090/metrics

# Check health
curl http://localhost:9090/healthz
```

### Grafana Dashboard

Example PromQL queries for dashboards:

```promql
# Current forwarded port
pia_forwarded_port

# Port refresh success rate
rate(pia_refresh_success_total[5m]) / (rate(pia_refresh_success_total[5m]) + rate(pia_refresh_failure_total[5m]))

# Time since last port update
time() - pia_last_update_timestamp_seconds

# qBittorrent update success rate
rate(pia_qbittorrent_update_success_total[5m])
```

## Troubleshooting

### Check Deployment Status

```bash
kubectl get pods -l app.kubernetes.io/name=pia-portforward
kubectl describe pod -l app.kubernetes.io/name=pia-portforward
```

### View Logs

```bash
kubectl logs -l app.kubernetes.io/name=pia-portforward -f
```

The logs will show:
- Gateway detection process
- Forwarded port number
- qBittorrent integration status
- Refresh cycles

### Common Issues

**"Could not detect gateway IP"**
- Ensure VPN is connected before starting
- Check logs for tested gateway candidates
- Set `pia.gateway` manually if needed

**"qBittorrent authentication failed"**
- Verify `qbittorrent.host` is correct and accessible
- Check `qbittorrent.user` and `qbittorrent.password`

## Development

### Testing Locally

```bash
# Lint the chart
helm lint ./chart

# Render templates
helm template pia-portforward ./chart \
  --set pia.user=p1234567 \
  --set pia.password=test

# Install from local chart
helm install pia-portforward ./chart \
  --set pia.user=p1234567 \
  --set pia.password=your_password \
  --dry-run --debug
```

### Publishing to OCI Registry

```bash
# Package the chart
helm package ./chart

# Login to registry
helm registry login ghcr.io -u USERNAME

# Push to registry
helm push pia-portforward-1.0.0.tgz oci://ghcr.io/00o-sh/charts
```

## License

MIT License - see [LICENSE](../LICENSE)
