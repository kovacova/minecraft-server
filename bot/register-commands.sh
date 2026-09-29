#!/bin/bash
# Mac/Linux twin of register-commands.ps1: tells Discord that your app has
# /start and /status. The token is used for this one request and never saved.
set -euo pipefail
read -rp "Application ID (Developer Portal > General Information): " app_id
read -rsp "Bot token (Developer Portal > Bot > Reset Token): " token; echo

curl -fsS -X PUT "https://discord.com/api/v10/applications/$app_id/commands" \
  -H "Authorization: Bot $token" -H "Content-Type: application/json" \
  -d '[{"name":"start","description":"Wake up the Minecraft server"},
       {"name":"status","description":"Is the Minecraft server on?"}]' |
  python3 -c 'import json,sys; [print("Registered /" + c["name"]) for c in json.load(sys.stdin)]'
