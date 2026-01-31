#!/usr/bin/env bash
set -euo pipefail

# Optimized deployment script for 1000+ concurrent users
# Automatically uses optimal Cloud Run settings

echo "=========================================="
echo "  XRAY Cloud Run - 1000+ User Optimized"
echo "=========================================="

PROTO="${PROTO:-vless}"
WSPATH="${WSPATH:-/ws}"
SERVICE="${SERVICE:-xray-optimized}"
IDX="${IDX:-1}"
REGION="${REGION:-us-central1}"
UUID="${UUID:-$(cat /proc/sys/kernel/random/uuid)}"

# -------- Optimized Performance Settings --------
MEMORY="2048"        # 2GB - Required for 1000+ concurrent users
CPU="2"              # 2 vCPU - Handle multiple connections efficiently
TIMEOUT="3600"       # 1 hour - For long-lived WebSocket connections
MAX_INSTANCES="100"  # Auto-scale up to 100 instances
CONCURRENCY="1000"   # 1000 concurrent requests per instance

echo "✅ Optimized Settings:"
echo "  Memory: ${MEMORY}MB"
echo "  CPU: ${CPU} cores"
echo "  Timeout: ${TIMEOUT}s"
echo "  Max Instances: ${MAX_INSTANCES}"
echo "  Max Concurrency: ${CONCURRENCY} requests/instance"
echo ""

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

# -------- Enable APIs --------
echo "⚙️  Enabling required APIs..."
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

# Ensure path begins with '/'
if [[ "${WSPATH}" != /* ]]; then
  WSPATH="/${WSPATH}"
fi

# -------- Optimized Xray Configuration --------
cat > config.json <<'XRAY_CONFIG'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [{
    "port": 8080,
    "listen": "0.0.0.0",
    "protocol": "__PROTO__",
    "settings": {
      __CLIENT_CONFIG__
    },
    "streamSettings": {
      "network": "ws",
      "security": "none",
      "wsSettings": {
        "path": "__WS_PATH__",
        "connectionReuse": true
      }
    },
    "sniffing": {
      "enabled": true,
      "destOverride": ["http", "tls"],
      "metadataOnly": false
    }
  }],
  "outbounds": [{
    "protocol": "freedom",
    "settings": {
      "domainStrategy": "UseIPv4"
    }
  }],
  "routing": {
    "rules": [{
      "type": "field",
      "outboundTag": "freedom",
      "domain": ["geosite:geolocation-!cn"]
    }]
  }
}
XRAY_CONFIG

# Replace template variables
sed -i "s|__PROTO__|$PROTO|g" config.json
sed -i "s|__CLIENT_CONFIG__|$CLIENT_CONFIG|g" config.json
sed -i "s|__WS_PATH__|$WSPATH|g" config.json

echo "✅ Generated optimized config.json"

# -------- Deploy to Cloud Run --------
echo "🚀 Deploying to Cloud Run with optimized settings..."
gcloud run deploy "$SERVICE" \
  --source . \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --memory "${MEMORY}Mi" \
  --cpu "$CPU" \
  --timeout "$TIMEOUT" \
  --max-instances "$MAX_INSTANCES" \
  --concurrency "$CONCURRENCY" \
  --quiet

# -------- Get URL --------
URL=$(gcloud run services describe "$SERVICE" --region "$REGION" --format="value(status.url)")
HOST="${URL#https://}"

echo "=========================================="
echo "✅ DEPLOYMENT SUCCESS - OPTIMIZED"
echo "=========================================="
echo "Protocol : $PROTO"
echo "Address  : $HOST"
echo "Port     : 443 (Cloud Run HTTPS)"
echo "UUID/PWD : $UUID"
echo "Path     : $WSPATH"
echo "Network  : WebSocket"
echo "TLS      : ON"
echo ""
echo "📊 Optimized Performance:"
echo "Memory      : ${MEMORY}MB"
echo "CPU         : ${CPU} cores"
echo "Timeout     : ${TIMEOUT}s"
echo "Max Instances: ${MAX_INSTANCES}"
echo "Concurrency : ${CONCURRENCY} requests/instance"
echo "Estimated   : ~100,000+ concurrent users"
echo "=========================================="

# -------- Generate Share Links --------
if [ "$PROTO" = "vless" ]; then
  VLESS_LINK="vless://${UUID}@${HOST}:443?type=ws&security=tls&path=${WSPATH}#xray-optimized"
  echo ""
  echo "📎 VLESS LINK:"
  echo "$VLESS_LINK"
elif [ "$PROTO" = "vmess" ]; then
  VMESS_JSON=$(cat <<EOF
{
  "v": "2",
  "ps": "$SERVICE",
  "add": "$HOST",
  "port": "443",
  "id": "$UUID",
  "aid": "0",
  "net": "ws",
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
elif [ "$PROTO" = "trojan" ]; then
  TROJAN_LINK="trojan://${UUID}@${HOST}:443?type=ws&security=tls&path=${WSPATH}#xray-optimized"
  echo ""
  echo "📎 TROJAN LINK:"
  echo "$TROJAN_LINK"
fi

echo "=========================================="
