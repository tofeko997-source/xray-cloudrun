FROM ghcr.io/xtls/xray-core:latest

# Copy template and entrypoint
COPY config.json.tpl /config.json.tpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 8080 9000

# Run entrypoint
ENTRYPOINT ["/entrypoint.sh"]
