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

# -------- WS Path --------
if [ "${INTERACTIVE}" = true ] && [ -z "${WSPATH:-}" ]; then
  read -rp "📡 WebSocket Path (default: /ws): " WSPATH
fi
WSPATH="${WSPATH:-/ws}"

# -------- Domain --------
if [ "${INTERACTIVE}" = true ] && [ -z "${DOMAIN:-}" ]; then
  read -rp "🌐 Custom Domain (empty = use Cloud Run URL): " DOMAIN
fi

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

# Ensure path begins with '/'
if [[ "${WSPATH}" != /* ]]; then
  WSPATH="/${WSPATH}"
fi

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
      "network": "ws",
      "security": "none",
      "wsSettings": {
        "path": "$WSPATH"
      }
    }
  }],
  "outbounds": [{
    "protocol": "freedom"
  }]
}
EOF



echo "🚀 Deploying XRAY to Cloud Run..."
gcloud run deploy "$SERVICE" \
  --source . \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --quiet

# -------- Get URL --------
URL=$(gcloud run services describe "$SERVICE" --region "$REGION" --format="value(status.url)")

if [ -n "${DOMAIN}" ]; then
  HOST="$DOMAIN"
else
  HOST="${URL#https://}"
fi

# -------- Output --------
echo "=========================================="
echo "✅ DEPLOYMENT SUCCESS"
echo "=========================================="
echo "Protocol : $PROTO"
echo "Address  : $HOST"
echo "Port     : 443 (Cloud Run HTTPS)"
echo "UUID/PWD : $UUID"
echo "Path     : $WSPATH"
echo "Network  : WebSocket"
echo "TLS      : ON"
echo "=========================================="

if [ "$PROTO" = "vmess" ]; then
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
fi