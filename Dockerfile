FROM ghcr.io/xtls/xray-core:latest

# Copy configuration template and entrypoint
COPY config.json.tpl /config.json.tpl
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Expose the port Cloud Run uses
EXPOSE 8080

# Use entrypoint to start xray
ENTRYPOINT ["/entrypoint.sh"]
