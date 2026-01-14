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

## Building

```bash
docker build -t pia-vpn:latest .
```

## Running

```bash
docker run --rm -it \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  --sysctl net.ipv4.conf.all.src_valid_mark=1 \
  --sysctl net.ipv6.conf.all.disable_ipv6=1 \
  -e PIA_USER=p1234567 \
  -e PIA_PASS=your_password \
  -e VPN_PROTOCOL=wireguard \
  -e PIA_PF=false \
  pia-vpn:latest
```

## Kubernetes Deployment

See `/kubernetes/apps/network/pia-vpn/` for Kubernetes manifests that integrate with:
- Multus for network attachment
- External-secrets for credential management
- 1Password for secret storage

## Source

Based on [pia-foss/manual-connections](https://github.com/pia-foss/manual-connections)
