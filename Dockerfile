FROM alpine:3.21

# Install required packages
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    wireguard-tools \
    openvpn \
    iptables \
    ip6tables \
    openresolv \
    ca-certificates \
    git \
    iproute2

# Clone PIA manual connections repository
WORKDIR /opt/pia
RUN git clone --depth 1 https://github.com/pia-foss/manual-connections.git . && \
    chmod +x *.sh

# Create entrypoint script and port forwarding loop
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY port-forward-loop.sh /usr/local/bin/port-forward-loop.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/port-forward-loop.sh

# Create directories for PIA config and port data
RUN mkdir -p /etc/pia /config

WORKDIR /opt/pia

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
