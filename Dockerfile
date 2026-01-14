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

# Create entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Create directory for PIA config
RUN mkdir -p /etc/pia

WORKDIR /opt/pia

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
