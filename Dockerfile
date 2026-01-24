FROM alpine:3.21

# OCI labels
LABEL org.opencontainers.image.title="PIA Port Forwarding Manager"
LABEL org.opencontainers.image.description="Lightweight container for managing PIA port forwarding with qBittorrent integration"
LABEL org.opencontainers.image.authors="00o-sh"
LABEL org.opencontainers.image.source="https://github.com/00o-sh/docker-pia-portforward"
LABEL org.opencontainers.image.licenses="MIT"

# Install required packages for port forwarding and monitoring
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    ca-certificates \
    iproute2 \
    socat \
    procps

# Create non-root user
RUN addgroup -g 1000 pia && \
    adduser -D -u 1000 -G pia pia

# Create directory for port data with proper permissions
RUN mkdir -p /config && \
    chown -R pia:pia /config

# Create entrypoint script and port forwarding loop
COPY --chown=pia:pia entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=pia:pia port-forward-loop.sh /usr/local/bin/port-forward-loop.sh
COPY --chown=pia:pia http-server.sh /usr/local/bin/http-server.sh
COPY --chown=pia:pia healthz.sh /usr/local/bin/healthz.sh
COPY --chown=pia:pia metrics.sh /usr/local/bin/metrics.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/port-forward-loop.sh \
    /usr/local/bin/http-server.sh /usr/local/bin/healthz.sh /usr/local/bin/metrics.sh

# Expose HTTP port for health checks and metrics
EXPOSE 9090

# Health check - verify port forwarding is working
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD /usr/local/bin/healthz.sh || exit 1

# Switch to non-root user
USER pia

WORKDIR /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
