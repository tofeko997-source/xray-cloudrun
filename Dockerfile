FROM ghcr.io/xtls/xray-core:latest

ENV PROTO=vless
ENV USER_ID=changeme
ENV WS_PATH=/ws

COPY config.json.tpl /config.json.tpl
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
