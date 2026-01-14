FROM alpine:3.21

# Install required packages for port forwarding only
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    ca-certificates \
    iproute2

# Create entrypoint script and port forwarding loop
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY port-forward-loop.sh /usr/local/bin/port-forward-loop.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/port-forward-loop.sh

# Create directory for port data
RUN mkdir -p /config

WORKDIR /

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
