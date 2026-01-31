FROM ghcr.io/xtls/xray-core:latest

# Use the generated config.json (created by install.sh) if present in build context
COPY config.json /etc/xray/config.json

# Run xray directly (no shell required in distroless image)
CMD ["xray", "run", "-config", "/etc/xray/config.json"]
