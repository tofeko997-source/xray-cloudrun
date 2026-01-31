FROM ghcr.io/xtls/xray-core:latest

# Use the generated config.json (created by install.sh) if present in build context
COPY config.json /etc/xray/config.json

# The base image already uses `xray` as the entrypoint. Provide only the args.
CMD ["run", "-config", "/etc/xray/config.json"]
