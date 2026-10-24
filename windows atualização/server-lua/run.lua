-- SPDX-License-Identifier: AGPL-3.0-only
-- Standalone LOCAL server CLI for automated integration tests.
-- Windows users normally use the opt-in LÖVE launcher instead.
local Socket=require("socket")
local Local=require("server-lua.local_server")
local server=Local.new({
 bind=assert(os.getenv("MOO_IO_BIND_IP"),"MOO_IO_BIND_IP required"),
 port=tonumber(os.getenv("PORT")) or 8080,
 roomCode=assert(os.getenv("MOO_IO_ROOM_CODE"),"MOO_IO_ROOM_CODE required"),
 mode=os.getenv("MOO_IO_NETWORK_MODE")=="vpn" and "vpn" or "lan",
 botCount=os.getenv("MOO_IO_BOT_COUNT") or "0",
 dataDir=assert(os.getenv("MOO_IO_LUA_DATA_DIR"),"MOO_IO_LUA_DATA_DIR required"),
 guiHost=true,log=function(message)print(message)end
})
local ok,err=server:start()
assert(ok,err)
print("MOOIO_LUA_SERVER_READY")
io.stdout:flush()
local good,reason=pcall(function()
 while server.host.listener do
  server:update()
  Socket.sleep(0.005)
 end
end)
server:close()
if not good then error(reason) end
