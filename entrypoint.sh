#!/usr/bin/env sh
set -eu

PROTO=${PROTO:-vless}
USER_ID=${USER_ID:-changeme}
WS_PATH=${WS_PATH:-/ws}

# ensure WS_PATH begins with /
case "$WS_PATH" in
  /*) ;;
  *) WS_PATH="/$WS_PATH" ;;
esac

# generate config
sed -e "s|__PROTO__|${PROTO}|g" \
    -e "s|__USER_ID__|${USER_ID}|g" \
    -e "s|__WS_PATH__|${WS_PATH}|g" \
    /config.json.tpl > /etc/xray/config.json

# exec xray from the base image
exec xray run -config /etc/xray/config.json
