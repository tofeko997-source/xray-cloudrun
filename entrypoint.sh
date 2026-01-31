#!/usr/bin/env bash
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

# ensure target directory exists
mkdir -p /etc/xray

if [ ! -f /config.json.tpl ]; then
  echo "❌ config.json.tpl not found in image" >&2
  exit 1
fi

sed -e "s|__PROTO__|${PROTO}|g" \
    -e "s|__USER_ID__|${USER_ID}|g" \
    -e "s|__WS_PATH__|${WS_PATH}|g" \
    /config.json.tpl > /etc/xray/config.json

# Start xray in background
xray run -config /etc/xray/config.json &
XRAY_PID=$!

# Start simple HTTP health check server on port 8080
(while true; do
  { echo -ne "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK"; } | nc -l -p 8080 -q 1 2>/dev/null || true
done) &

# Wait for xray process
wait $XRAY_PID
