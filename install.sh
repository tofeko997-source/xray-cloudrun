#!/usr/bin/env bash
set -euo pipefail

# Detect interactive mode (has a TTY). When non-interactive (e.g. `curl | bash`),
# the script will read configuration from environment variables or use defaults.
if [ -t 0 ] && [ -t 1 ]; then
  INTERACTIVE=true
else
  INTERACTIVE=false
fi

# Non-interactive usage examples:
#  PROTO=vmess WSPATH=/ws DOMAIN=example.com SERVICE=my-service IDX=3 bash install.sh
#  PROTO=vmess WSPATH=/ws DOMAIN=example.com SERVICE=my-service IDX=3 curl -fsSL https://... | bash

echo "=========================================="
echo "  XRAY Cloud Run (VLESS / VMESS / TROJAN)"
echo "=========================================="

# -------- Telegram Bot --------
if [ "${INTERACTIVE}" = true ] && [ -z "${BOT_TOKEN:-}" ]; then
  read -rp "🤖 Telegram Bot Token (optional, press Enter to skip): " BOT_TOKEN
fi
BOT_TOKEN="${BOT_TOKEN:-}"

if [ "${INTERACTIVE}" = true ] && [ -z "${CHAT_ID:-}" ] && [ -n "${BOT_TOKEN}" ]; then
  read -rp "💬 Telegram Chat ID (optional): " CHAT_ID
fi
CHAT_ID="${CHAT_ID:-}"

# Telegram send function
send_telegram() {
  if [ -z "${BOT_TOKEN}" ] || [ -z "${CHAT_ID}" ]; then
    return 0
  fi
  
  MESSAGE="$1"
  # URL encode the message properly
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}" \
    -d "parse_mode=HTML" \
    > /dev/null 2>&1
}

# -------- Protocol --------
if [ "${INTERACTIVE}" = true ] && [ -z "${PROTO_CHOICE:-}" ]; then
  echo ""
  echo "🔐 Choose Protocol:"
  echo "1) VLESS"
  echo "2) VMESS"
  echo "3) TROJAN"
  read -rp "Select protocol [1-3] (default: 1): " PROTO_CHOICE
fi
PROTO_CHOICE="${PROTO_CHOICE:-1}"

case "$PROTO_CHOICE" in
  1)
    PROTO="vless"
    ;;
  2)
    PROTO="vmess"
    ;;
  3)
    PROTO="trojan"
    ;;
  *)
    echo "❌ Invalid protocol selection"
    exit 1
    ;;
esac

# -------- Network Type --------
if [ "${INTERACTIVE}" = true ] && [ -z "${NETWORK:-}" ]; then
  echo ""
  echo "🌐 Choose Network Type:"
  echo "1) WebSocket (ws)"
  echo "2) TCP"
  echo "3) gRPC"
  read -rp "Select network type [1-3] (default: 1): " NETWORK_CHOICE
fi
NETWORK_CHOICE="${NETWORK_CHOICE:-1}"

case "$NETWORK_CHOICE" in
  1)
    NETWORK="ws"
    NETWORK_DISPLAY="WebSocket"
    ;;
  2)
    NETWORK="tcp"
    NETWORK_DISPLAY="TCP"
    ;;
  3)
    NETWORK="grpc"
    NETWORK_DISPLAY="gRPC"
    ;;
  *)
    echo "❌ Invalid network type selection"
    exit 1
    ;;
esac

# -------- WS Path --------
if [ "$NETWORK" = "ws" ]; then
  if [ "${INTERACTIVE}" = true ] && [ -z "${WSPATH:-}" ]; then
    read -rp "📡 WebSocket Path (default: /ws): " WSPATH
  fi
  WSPATH="${WSPATH:-/ws}"
elif [ "$NETWORK" = "grpc" ]; then
  if [ "${INTERACTIVE}" = true ] && [ -z "${WSPATH:-}" ]; then
    read -rp "🔌 gRPC Service Name (default: xray): " WSPATH
  fi
  WSPATH="${WSPATH:-xray}"
else
  WSPATH=""
fi

# -------- Custom Hostname (optional) --------
if [ "${INTERACTIVE}" = true ] && [ -z "${CUSTOM_HOST:-}" ]; then
  echo ""
  echo "🌐 Custom Hostname Options:"
  echo "   Leave blank to use Cloud Run default: SERVICE-PROJECT_ID.REGION.run.app"
  echo "   Or enter a custom domain: my-proxy.example.com"
  read -rp "Custom hostname (optional): " CUSTOM_HOST
fi
CUSTOM_HOST="${CUSTOM_HOST:-}"

# -------- Service Name --------
if [ "${INTERACTIVE}" = true ] && [ -z "${SERVICE:-}" ]; then
  read -rp "🪪 Cloud Run Service Name (default: xray-ws): " SERVICE
fi
SERVICE="${SERVICE:-xray-ws}"

# Validate service name format
if ! [[ "$SERVICE" =~ ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ ]]; then
  echo "❌ Invalid service name. Use lowercase alphanumeric and hyphens only (1-63 chars)."
  exit 1
fi

# -------- Optional Link Parameters --------
if [ "${INTERACTIVE}" = true ] && [ -z "${SNI_CHOICE:-}" ]; then
  echo ""
  echo "🔒 SNI (Server Name Indication):"
  echo "1) m.youtube.com"
  echo "2) www.google.com"
  echo "3) www.bing.com"
  echo "4) Leave blank (no SNI)"
  read -rp "Select SNI or custom [1-4] (default: 4): " SNI_CHOICE
fi
SNI_CHOICE="${SNI_CHOICE:-4}"

case "$SNI_CHOICE" in
  1)
    SNI="m.youtube.com"
    ;;
  2)
    SNI="www.google.com"
    ;;
  3)
    SNI="www.facebook.com"
    ;;
  4)
    SNI=""
    ;;
  *)
    SNI="$SNI_CHOICE"
    ;;
esac

# -------- ALPN --------
if [ "${INTERACTIVE}" = true ] && [ -z "${ALPN:-}" ]; then
  echo ""
  echo "📡 Choose ALPN (Application Layer Protocol):"
  echo "1) default"
  echo "2) h2,http/1.1"
  echo "3) h2"
  echo "4) http/1.1"
  read -rp "Select ALPN [1-4] (default: 1): " ALPN_CHOICE
fi
ALPN_CHOICE="${ALPN_CHOICE:-1}"

case "$ALPN_CHOICE" in
  1)
    ALPN="default"
    ;;
  2)
    ALPN="h2,http/1.1"
    ;;
  3)
    ALPN="h2"
    ;;
  4)
    ALPN="http/1.1"
    ;;
  *)
    echo "❌ Invalid ALPN selection"
    exit 1
    ;;
esac

if [ "${INTERACTIVE}" = true ] && [ -z "${CUSTOM_ID:-}" ]; then
  read -rp "🏷️  Custom Identifier for Link (e.g., S103, optional): " CUSTOM_ID
fi
CUSTOM_ID="${CUSTOM_ID:-}"

# -------- UUID --------
UUID=$(cat /proc/sys/kernel/random/uuid)

# -------- Region Select --------
echo ""
AVAILABLE_REGIONS=("us-central1" "us-east1" "us-west1" "us-south1" "europe-west1" "europe-west4" "asia-east1" "asia-northeast1" "asia-southeast1")

if [ "${INTERACTIVE}" = true ] && [ -z "${IDX:-}" ]; then
  echo "🌍 Available regions:"
  i=1
  for r in "${AVAILABLE_REGIONS[@]}"; do
    echo "$i) $r"
    ((i++))
  done
  read -rp "Select region [1-${#AVAILABLE_REGIONS[@]}] (default: 1): " IDX
fi

IDX="${IDX:-1}"

# Validate region selection
if [[ ! "$IDX" =~ ^[0-9]+$ ]] || [ "$IDX" -lt 1 ] || [ "$IDX" -gt ${#AVAILABLE_REGIONS[@]} ]; then
  echo "❌ Invalid region selection"
  exit 1
fi

REGION="${AVAILABLE_REGIONS[$((IDX-1))]}"
echo "✅ Selected region: $REGION"

# -------- Performance Settings --------
echo ""
echo "⚙️  Performance Configuration (optional, press Enter to skip):"

if [ "${INTERACTIVE}" = true ] && [ -z "${MEMORY:-}" ]; then
  read -rp "💾 Memory (MB) [e.g., 512, 1024, 2048]: " MEMORY
fi
MEMORY="${MEMORY}"

if [ "${INTERACTIVE}" = true ] && [ -z "${CPU:-}" ]; then
  read -rp "⚙️  CPU cores [e.g., 0.5, 1, 2]: " CPU
fi
CPU="${CPU}"

if [ "${INTERACTIVE}" = true ] && [ -z "${TIMEOUT:-}" ]; then
  read -rp "⏱️  Request timeout (seconds) [e.g., 300, 1800, 3600]: " TIMEOUT
fi
TIMEOUT="${TIMEOUT}"

if [ "${INTERACTIVE}" = true ] && [ -z "${MAX_INSTANCES:-}" ]; then
  read -rp "📊 Max instances [e.g., 5, 10, 20, 50]: " MAX_INSTANCES
fi
MAX_INSTANCES="${MAX_INSTANCES}"

if [ "${INTERACTIVE}" = true ] && [ -z "${CONCURRENCY:-}" ]; then
  read -rp "🔗 Max concurrent requests per instance [e.g., 50, 100, 500, 1000]: " CONCURRENCY
fi
CONCURRENCY="${CONCURRENCY}"

# Show what was selected
echo ""
echo "✅ Selected configuration:"
[ -n "${MEMORY}" ] && echo "   Memory: ${MEMORY}MB" || echo "   Memory: (will use Cloud Run default)"
[ -n "${CPU}" ] && echo "   CPU: ${CPU} cores" || echo "   CPU: (will use Cloud Run default)"
[ -n "${TIMEOUT}" ] && echo "   Timeout: ${TIMEOUT}s" || echo "   Timeout: (will use Cloud Run default)"
[ -n "${MAX_INSTANCES}" ] && echo "   Max instances: ${MAX_INSTANCES}" || echo "   Max instances: (will use Cloud Run default)"
[ -n "${CONCURRENCY}" ] && echo "   Max concurrency: ${CONCURRENCY}" || echo "   Max concurrency: (will use Cloud Run default)"

# -------- Sanity checks --------
if ! command -v gcloud >/dev/null 2>&1; then
  echo "❌ gcloud CLI not found. Install and authenticate first."
  exit 1
fi

PROJECT=$(gcloud config get-value project 2>/dev/null || true)
if [ -z "${PROJECT:-}" ]; then
  echo "❌ No GCP project set. Run 'gcloud init' or 'gcloud config set project PROJECT_ID'."
  exit 1
fi

# -------- APIs --------
echo "⚙️ Enabling required APIs..."
gcloud services enable run.googleapis.com cloudbuild.googleapis.com --quiet

echo "🚀 Deploying XRAY to Cloud Run..."

# Build deploy command with optional parameters
DEPLOY_ARGS=(
  "--source" "."
  "--region" "$REGION"
  "--platform" "managed"
  "--allow-unauthenticated"
)

[ -n "${MEMORY}" ] && DEPLOY_ARGS+=("--memory" "${MEMORY}Mi")
[ -n "${CPU}" ] && DEPLOY_ARGS+=("--cpu" "${CPU}")
[ -n "${TIMEOUT}" ] && DEPLOY_ARGS+=("--timeout" "${TIMEOUT}")
[ -n "${MAX_INSTANCES}" ] && DEPLOY_ARGS+=("--max-instances" "${MAX_INSTANCES}")
[ -n "${CONCURRENCY}" ] && DEPLOY_ARGS+=("--concurrency" "${CONCURRENCY}")

DEPLOY_ARGS+=("--set-env-vars" "PROTO=${PROTO},USER_ID=${UUID},WS_PATH=${WSPATH},NETWORK=${NETWORK}")
DEPLOY_ARGS+=("--quiet")

gcloud run deploy "$SERVICE" "${DEPLOY_ARGS[@]}"

# -------- Get URL --------
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project 2>/dev/null) --format="value(projectNumber)" 2>/dev/null)

# Use custom hostname if provided, otherwise use Cloud Run default
if [ -n "${CUSTOM_HOST}" ]; then
  HOST="${CUSTOM_HOST}"
  echo "Service URL: https://${HOST}"
  echo "✅ Using custom hostname: ${HOST}"
else
  HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
  echo "Service URL: https://${HOST}"
  echo "✅ Using Cloud Run default: ${HOST}"
fi

# -------- Output --------
echo "=========================================="
echo "✅ DEPLOYMENT SUCCESS"
echo "=========================================="
echo "Protocol : $PROTO"
echo "Address  : $HOST"
echo "Port     : 443 (Cloud Run HTTPS)"
echo "UUID/PWD : $UUID"
if [ "$NETWORK" = "ws" ]; then
  echo "Path     : $WSPATH"
elif [ "$NETWORK" = "grpc" ]; then
  echo "Service  : $WSPATH"
fi
echo "Network  : $NETWORK_DISPLAY"
echo "TLS      : ON"
if [ -n "${MEMORY}${CPU}${TIMEOUT}${MAX_INSTANCES}${CONCURRENCY}" ]; then
  echo ""
  echo "⚙️  Configuration Applied:"
  [ -n "${MEMORY}" ] && echo "Memory      : ${MEMORY}MB"
  [ -n "${CPU}" ] && echo "CPU         : ${CPU} cores"
  [ -n "${TIMEOUT}" ] && echo "Timeout     : ${TIMEOUT}s"
  [ -n "${MAX_INSTANCES}" ] && echo "Max Instances: ${MAX_INSTANCES}"
  [ -n "${CONCURRENCY}" ] && echo "Concurrency : ${CONCURRENCY} requests/instance"
fi
echo "=========================================="

# -------- Generate Protocol Links --------
# -------- Generate Protocol Links --------
# Build query parameters based on network type
if [ "$NETWORK" = "ws" ]; then
  QUERY_PARAMS="type=ws&security=tls&path=${WSPATH}"
  if [ -n "${SNI}" ]; then
    QUERY_PARAMS="${QUERY_PARAMS}&sni=${SNI}"
  fi
  if [ -n "${ALPN}" ]; then
    QUERY_PARAMS="${QUERY_PARAMS}&alpn=${ALPN}"
  fi
elif [ "$NETWORK" = "tcp" ]; then
  QUERY_PARAMS="type=tcp&security=tls&headerType=none"
  if [ -n "${SNI}" ]; then
    QUERY_PARAMS="${QUERY_PARAMS}&sni=${SNI}"
  fi
  if [ -n "${ALPN}" ]; then
    QUERY_PARAMS="${QUERY_PARAMS}&alpn=${ALPN}"
  fi
elif [ "$NETWORK" = "grpc" ]; then
  QUERY_PARAMS="type=grpc&security=tls&serviceName=${WSPATH}"
  if [ -n "${SNI}" ]; then
    QUERY_PARAMS="${QUERY_PARAMS}&sni=${SNI}"
  fi
  if [ -n "${ALPN}" ]; then
    QUERY_PARAMS="${QUERY_PARAMS}&alpn=${ALPN}"
  fi
fi

# Build fragment with custom ID
LINK_FRAGMENT="xray"
if [ -n "${CUSTOM_ID}" ]; then
  LINK_FRAGMENT="(${CUSTOM_ID})"
fi

if [ "$PROTO" = "vless" ]; then
  VLESS_LINK="vless://${UUID}@${HOST}:443?${QUERY_PARAMS}#${LINK_FRAGMENT}"
  echo ""
  echo "📎 VLESS LINK:"
  echo "$VLESS_LINK"
  SHARE_LINK="$VLESS_LINK"
elif [ "$PROTO" = "vmess" ]; then
  VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "$SERVICE",
  "add": "$HOST",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "$NETWORK",
  "type": "none",
  "host": "$HOST",
  "path": "$WSPATH",
  "tls": "tls"
}
EOF
)
  if [ -n "${SNI}" ]; then
    VMESS_JSON=$(echo "$VMESS_JSON" | sed "s/}/,\"sni\":\"${SNI}\"}/")
  fi
  if [ -n "${ALPN}" ]; then
    VMESS_JSON=$(echo "$VMESS_JSON" | sed "s/}/,\"alpn\":\"${ALPN}\"}/")
  fi
  VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 -w 0)"
  echo ""
  echo "📎 VMESS LINK:"
  echo "$VMESS_LINK"
  SHARE_LINK="$VMESS_LINK"
elif [ "$PROTO" = "trojan" ]; then
  TROJAN_LINK="trojan://${UUID}@${HOST}:443?${QUERY_PARAMS}#${LINK_FRAGMENT}"
  echo ""
  echo "📎 TROJAN LINK:"
  echo "$TROJAN_LINK"
  SHARE_LINK="$TROJAN_LINK"
fi

# -------- Generate Data URIs --------
echo ""
echo "📊 DATA URIs:"
echo "=========================================="

# Prepare path/service info
PATH_INFO=""
if [ "$NETWORK" = "ws" ]; then
  PATH_INFO="Path: ${WSPATH}"
elif [ "$NETWORK" = "grpc" ]; then
  PATH_INFO="Service: ${WSPATH}"
fi

# Prepare optional params info
OPTIONAL_INFO=""
if [ -n "${SNI}" ]; then
  OPTIONAL_INFO="${OPTIONAL_INFO}SNI: ${SNI}\n"
fi
if [ -n "${ALPN}" ] && [ "${ALPN}" != "h2,http/1.1" ]; then
  OPTIONAL_INFO="${OPTIONAL_INFO}ALPN: ${ALPN}\n"
fi
if [ -n "${CUSTOM_ID}" ]; then
  OPTIONAL_INFO="${OPTIONAL_INFO}Custom ID: ${CUSTOM_ID}\n"
fi

# Data URI 1: Plain text configuration
CONFIG_TEXT="✅ XRAY DEPLOYMENT SUCCESS

Protocol: ${PROTO^^}
Host: ${HOST}
Port: 443
UUID/Password: ${UUID}
${PATH_INFO}
Network: ${NETWORK_DISPLAY} + TLS
${OPTIONAL_INFO}Share Link: ${SHARE_LINK}"

DATA_URI_TEXT="data:text/plain;base64,$(echo -n "$CONFIG_TEXT" | base64 -w 0)"
echo "📋 Data URI (Text):"
echo "$DATA_URI_TEXT"
echo ""

# Data URI 2: JSON configuration
if [ "$NETWORK" = "ws" ]; then
  CONFIG_JSON=$(cat <<EOF
{
  "protocol": "${PROTO}",
  "host": "${HOST}",
  "port": 443,
  "uuid_password": "${UUID}",
  "path": "${WSPATH}",
  "network": "${NETWORK}",
  "network_display": "${NETWORK_DISPLAY}",
  "tls": true,
  "sni": "${SNI}",
  "alpn": "${ALPN}",
  "custom_id": "${CUSTOM_ID}",
  "share_link": "${SHARE_LINK}"
}
EOF
)
elif [ "$NETWORK" = "grpc" ]; then
  CONFIG_JSON=$(cat <<EOF
{
  "protocol": "${PROTO}",
  "host": "${HOST}",
  "port": 443,
  "uuid_password": "${UUID}",
  "service_name": "${WSPATH}",
  "network": "${NETWORK}",
  "network_display": "${NETWORK_DISPLAY}",
  "tls": true,
  "sni": "${SNI}",
  "alpn": "${ALPN}",
  "custom_id": "${CUSTOM_ID}",
  "share_link": "${SHARE_LINK}"
}
EOF
)
else
  CONFIG_JSON=$(cat <<EOF
{
  "protocol": "${PROTO}",
  "host": "${HOST}",
  "port": 443,
  "uuid_password": "${UUID}",
  "network": "${NETWORK}",
  "network_display": "${NETWORK_DISPLAY}",
  "tls": true,
  "sni": "${SNI}",
  "alpn": "${ALPN}",
  "custom_id": "${CUSTOM_ID}",
  "share_link": "${SHARE_LINK}"
}
EOF
)
fi

DATA_URI_JSON="data:application/json;base64,$(echo -n "$CONFIG_JSON" | base64 -w 0)"
echo "📊 Data URI (JSON):"
echo "$DATA_URI_JSON"
echo "=========================================="

# -------- Send to Telegram --------
if [ -n "${BOT_TOKEN}" ] && [ -n "${CHAT_ID}" ]; then
  # Send only the copy link
  send_telegram "<b>🔗 Copy Link:</b>
 <code>``` ${SHARE_LINK} ```</code>"
fi