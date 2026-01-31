{
  "inbounds": [
    {
      "port": 9000,
      "listen": "127.0.0.1",
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
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "serverName": "__SNI__"
        },
        "wsSettings": {
          "path": "__WS_PATH__"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}