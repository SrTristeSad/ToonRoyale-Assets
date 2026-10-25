#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
command -v lua5.4 >/dev/null || { echo "Instale lua5.4" >&2; exit 1; }
lua5.4 -e 'require("socket")' || { echo "Instale lua-socket" >&2; exit 1; }
mkdir -p dados-lua
export MOO_IO_BIND_IP="${MOO_IO_BIND_IP:-127.0.0.1}"
export MOO_IO_ROOM_CODE="${MOO_IO_ROOM_CODE:-$(head -c 12 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
export MOO_IO_NETWORK_MODE="${MOO_IO_NETWORK_MODE:-lan}"
export MOO_IO_BOT_COUNT="${MOO_IO_BOT_COUNT:-0}"
export MOO_IO_LUA_DATA_DIR="$PWD/dados-lua"
export PORT="${PORT:-8080}"
unset MOO_IO_V2_PRIVATE_ROOM || true
printf 'Servidor Lua LOCAL: %s:%s codigo %s\n' "$MOO_IO_BIND_IP" "$PORT" "$MOO_IO_ROOM_CODE"
exec lua5.4 server-lua/run.lua
