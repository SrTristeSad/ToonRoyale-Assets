-- Runtime integration of the exact Android Lua client and Windows-derived
-- authoritative Lua server. Unlike the prior smoke tests, this requires a
-- real HTTP join -> WebSocket upgrade -> keyed handshake -> M -> C/D.
-- Run with MOO_IO_E2E_PORT and a listening server-lua/run.lua process.
package.path="./?.lua;./?/init.lua;"..package.path
local Socket=require("socket")
local Sha256=require("server-lua.protocol.sha256")
local Pack=require("src.protocol.msgpack")
love={data={hash=function(algorithm,data)
  assert(algorithm=="sha256")
  return Sha256.digest(data)
end}}
local Original=require("src.net.original_client")
local port=tonumber(os.getenv("MOO_IO_E2E_PORT")) or 18978
local client=Original.new({
  host="127.0.0.1",port=port,server="LC",
  inviteCode="testing42",autoSpawn=false
})
local ok,why=client:connect()
assert(ok,"Android client failed to request real local ticket: "..tostring(why))
local start=Socket.gettime()
local spawned,hasC,hasD,hasA=false,false,false,false
local counts={}
local remaining=12
while Socket.gettime()-start<remaining do
  client:update()
  if client.state=="keyed_transport" and not spawned then
    local sent,err=client:spawn({name="Android local CI",skin=0})
    assert(sent,"Android client could not send actual M packet: "..tostring(err))
    spawned=true
  end
  for _,evt in ipairs(client:drain()) do
    if evt.kind=="game_packet" then
      local p=evt.data
      counts[p.name]=(counts[p.name] or 0)+1
      if p.name=="C" then hasC=true
      elseif p.name=="D" then hasD=true
      elseif p.name=="a" then hasA=true end
    end
  end
  if client.state=="failed" or client.state=="closed"
     or client.state=="blocked" then
    error("Android client disconnected while joining real Lua server: "..
      tostring(client.state).." - "..tostring(client.error or client.status))
  end
  if hasC and (hasD or hasA) then break end
  Socket.sleep(.01)
end
assert(spawned and hasC and (hasD or hasA),
  "Server did not confirm gameplay; state="..tostring(client.state)..
    " status="..tostring(client.status)..
    " C="..tostring(hasC).." D="..tostring(hasD)..
    " a="..tostring(hasA))
-- The connection must survive real ongoing gameplay packets, not merely C/D.
local untilTime=Socket.gettime()+1.2
local sentMove=false
while Socket.gettime()<untilTime do
  if not sentMove then
    local sent,err=client:send("9",{Pack.null})
    assert(sent,"Server gameplay input failed: "..tostring(err))
    sentMove=true
  end
  client:update()
  if client.state=="failed" or client.state=="closed" or
     client.state=="blocked" then
    error("Socket closed during live gameplay: "..tostring(client.error))
  end
  Socket.sleep(.01)
end
client:close()
print("ANDROID LUA REAL CLIENT E2E PASS: ticket + WebSocket + M + C + D/a + gameplay keepalive")
