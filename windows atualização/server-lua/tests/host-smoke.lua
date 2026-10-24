-- SPDX-License-Identifier: AGPL-3.0-only
-- Integration test fixture. Never enabled in the shipped client.
local socket=require("socket")
local Host=require("server-lua.net.host")
local build={buildId="testbuild01",salt=0x12345678,constants={1,2,3,4,5,6,7,8},
  rounds=5,tapA=1,tapB=3,rotA=9,rotB=17,mult=733335361}
local h=Host.new({
  bind="127.0.0.1",port=18943,roomCode="testing42",capacity=40,build=build,
  onConnect=function(peer,ticket) assert(ticket.did) end,
  onPacket=function(peer,name,args) if name=="0" then assert(peer:send("0",{})) end end
})
local ok,why=h:start()
assert(ok,why)
print("LUA_HOST_READY")
io.stdout:flush()
local at=socket.gettime()+12
while socket.gettime()<at do
  h:update()
  socket.sleep(0.005)
end
h:close()
