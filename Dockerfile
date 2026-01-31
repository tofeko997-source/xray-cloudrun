FROM ghcr.io/xtls/xray-core:latest

# Install netcat for health check
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*

# Copy template and entrypoint
COPY config.json.tpl /config.json.tpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Health check for Cloud Run
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD nc -z 127.0.0.1 8080 || exit 1

# Run entrypoint
CMD ["/entrypoint.sh"]
