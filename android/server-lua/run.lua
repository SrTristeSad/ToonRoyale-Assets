-- SPDX-License-Identifier: AGPL-3.0-only
-- Standalone LOCAL server CLI for automated integration tests.
-- Windows users run the dedicated LÖVE Lua server by default.
local Socket=require("socket")
local Local=require("server-lua.local_server")
local server=Local.new({
 bind=assert(os.getenv("MOO_IO_BIND_IP"),"MOO_IO_BIND_IP required"),
 port=tonumber(os.getenv("PORT")) or 8080,
 roomCode=assert(os.getenv("MOO_IO_ROOM_CODE"),"MOO_IO_ROOM_CODE required"),
 mode=os.getenv("MOO_IO_NETWORK_MODE")=="vpn" and "vpn" or "lan",
 botCount=os.getenv("MOO_IO_BOT_COUNT") or "0",
 difficulty=os.getenv("MOO_IO_DIFFICULTY") or "normal",
 modIds=os.getenv("MOO_IO_MODS") or "",
 mapId=os.getenv("MOO_IO_MAP_ID") or "",
 dataDir=assert(os.getenv("MOO_IO_LUA_DATA_DIR"),"MOO_IO_LUA_DATA_DIR required"),
 protocolBuildFile=os.getenv("PROTOCOL_BUILD_FILE"),
 rotateBuild=(os.getenv("ROTATE_BUILD")~=nil
    and os.getenv("ROTATE_BUILD")~=""
    and os.getenv("ROTATE_BUILD")~="0"),
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
