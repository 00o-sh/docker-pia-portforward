FROM alpine:3.21

# OCI labels
LABEL org.opencontainers.image.title="PIA Port Forwarding Manager"
LABEL org.opencontainers.image.description="Lightweight container for managing PIA port forwarding with qBittorrent integration"
LABEL org.opencontainers.image.authors="00o-sh"
LABEL org.opencontainers.image.source="https://github.com/00o-sh/docker-pia-portforward"
LABEL org.opencontainers.image.licenses="MIT"

# Install required packages for port forwarding only
# hadolint ignore=DL3018
# Versions not pinned intentionally to receive security updates from base image.
# These are stable utilities (bash, curl, jq) with minimal API surface.
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    ca-certificates \
    iproute2

# Create non-root user
RUN addgroup -g 1000 pia && \
    adduser -D -u 1000 -G pia pia

# Create directory for port data with proper permissions
RUN mkdir -p /config && \
    chown -R pia:pia /config

# Create entrypoint script and port forwarding loop
COPY --chown=pia:pia entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=pia:pia port-forward-loop.sh /usr/local/bin/port-forward-loop.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/port-forward-loop.sh

# Switch to non-root user
USER pia

WORKDIR /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
