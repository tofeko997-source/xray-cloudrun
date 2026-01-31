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
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${MESSAGE}" \
    -d parse_mode="HTML" \
    > /dev/null 2>&1
}

# -------- Protocol --------
if [ "${INTERACTIVE}" = true ] && [ -z "${PROTO:-}" ]; then
  read -rp "🔐 Choose Protocol (vless/vmess/trojan) [vless]: " PROTO
fi
PROTO="${PROTO:-vless}"
PROTO="${PROTO,,}"

# Validate protocol
if [[ ! "$PROTO" =~ ^(vless|vmess|trojan)$ ]]; then
  echo "❌ Invalid protocol: '$PROTO'"
  exit 1
fi

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

# -------- Domain --------
# Always use Cloud Run default URL
DOMAIN=""

# -------- Service Name --------
if [ "${INTERACTIVE}" = true ] && [ -z "${SERVICE:-}" ]; then
  read -rp "🪪 Service Name (default: xray-ws): " SERVICE
fi
SERVICE="${SERVICE:-xray-ws}"

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

# -------- Xray Config --------
if [ "$PROTO" = "trojan" ]; then
  CLIENT_CONFIG=$(cat <<EOF
"clients": [{
  "password": "$UUID"
}]
EOF
)
elif [ "$PROTO" = "vless" ]; then
  CLIENT_CONFIG=$(cat <<EOF
"clients": [{
  "id": "$UUID"
}],
"decryption": "none"
EOF
)
else # vmess
  CLIENT_CONFIG=$(cat <<EOF
"clients": [{
  "id": "$UUID"
}]
EOF
)
fi

# Ensure path begins with '/' for WebSocket
if [ "$NETWORK" = "ws" ] && [[ "${WSPATH}" != /* ]]; then
  WSPATH="/${WSPATH}"
fi

# Build streamSettings based on network type
if [ "$NETWORK" = "ws" ]; then
  STREAM_SETTINGS=$(cat <<'EOF'
      "network": "ws",
      "security": "tls",
      "wsSettings": {
        "path": "$WSPATH"
      }
EOF
)
elif [ "$NETWORK" = "tcp" ]; then
  STREAM_SETTINGS=$(cat <<'EOF'
      "network": "tcp",
      "security": "tls",
      "tcpSettings": {
        "header": {
          "type": "none"
        }
      }
EOF
)
elif [ "$NETWORK" = "grpc" ]; then
  STREAM_SETTINGS=$(cat <<'EOF'
      "network": "grpc",
      "security": "tls",
      "grpcSettings": {
        "serviceName": "$WSPATH"
      }
EOF
)
fi

# Replace $WSPATH in stream settings
STREAM_SETTINGS="${STREAM_SETTINGS//\$WSPATH/$WSPATH}"

cat > config.json <<EOF
{
  "inbounds": [{
    "port": 8080,
    "listen": "0.0.0.0",
    "protocol": "$PROTO",
    "settings": {
      $CLIENT_CONFIG
    },
    "streamSettings": {
      $STREAM_SETTINGS
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF



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

DEPLOY_ARGS+=("--quiet")

gcloud run deploy "$SERVICE" "${DEPLOY_ARGS[@]}"

# -------- Get URL --------
PROJECT_NUMBER=$(gcloud projects describe $(gcloud config get-value project 2>/dev/null) --format="value(projectNumber)" 2>/dev/null)
HOST="${SERVICE}-${PROJECT_NUMBER}.${REGION}.run.app"
echo "Service URL: https://${HOST}"
echo "✅ Using primary domain: ${HOST}"

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
elif [ "$NETWORK" = "tcp" ]; then
  QUERY_PARAMS="type=tcp&security=tls"
elif [ "$NETWORK" = "grpc" ]; then
  QUERY_PARAMS="type=grpc&security=tls&serviceName=${WSPATH}"
fi

if [ "$PROTO" = "vless" ]; then
  VLESS_LINK="vless://${UUID}@${HOST}:443?${QUERY_PARAMS}#xray"
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
  VMESS_LINK="vmess://$(echo "$VMESS_JSON" | base64 -w 0)"
  echo ""
  echo "📎 VMESS LINK:"
  echo "$VMESS_LINK"
  SHARE_LINK="$VMESS_LINK"
elif [ "$PROTO" = "trojan" ]; then
  TROJAN_LINK="trojan://${UUID}@${HOST}:443?${QUERY_PARAMS}#xray"
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

# Data URI 1: Plain text configuration
CONFIG_TEXT="✅ XRAY DEPLOYMENT SUCCESS

Protocol: ${PROTO^^}
Host: ${HOST}
Port: 443
UUID/Password: ${UUID}
${PATH_INFO}
Network: ${NETWORK_DISPLAY} + TLS"

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
  # Build the main message with path/service info
  if [ "$NETWORK" = "ws" ]; then
    TELEGRAM_PATH="<b>Path:</b> <code>${WSPATH}</code>"
  elif [ "$NETWORK" = "grpc" ]; then
    TELEGRAM_PATH="<b>Service:</b> <code>${WSPATH}</code>"
  else
    TELEGRAM_PATH=""
  fi
  
  send_telegram "✅ <b>XRAY DEPLOYMENT SUCCESS</b>

<b>Protocol:</b> <code>${PROTO^^}</code>
<b>Host:</b> <code>${HOST}</code>
<b>Port:</b> <code>443</code>
<b>UUID/Password:</b> <code>${UUID}</code>
${TELEGRAM_PATH}
<b>Network:</b> ${NETWORK_DISPLAY} + TLS"
  
  send_telegram "<b>🔗 Share Link:</b>
<code>${SHARE_LINK}</code>"
  
  send_telegram "<b>📊 Data URIs:</b>

<b>Text Format:</b>
<code>${DATA_URI_TEXT}</code>

<b>JSON Format:</b>
<code>${DATA_URI_JSON}</code>"
fi