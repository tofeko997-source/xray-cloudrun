{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 8080,
      "listen": "0.0.0.0",
      "protocol": "__PROTO__",
      "settings": {
        "clients": [
          {
            "id": "__USER_ID__",
            "password": "__USER_ID__"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "__NETWORK__",
        "security": "none",
        "tcpSettings": {
          "header": {
            "type": "none"
          }
        },
        "wsSettings": {
          "path": "__WS_PATH__"
        },
        "grpcSettings": {
          "serviceName": "__WS_PATH__"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
