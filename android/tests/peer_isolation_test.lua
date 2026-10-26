-- Android room safety: invalid or abusive peers never terminate all
-- connections. Run against the real Lua socket/frame gateway.
package.path="./?.lua;./?/init.lua;"..package.path
local Host=require("server-lua.net.host")
local Frames=require("src.net.websocket_frames")
local received,disconnected=0,0
local room=Host.new({
  bind="127.0.0.1",mode="lan",roomCode="testing42",
  rooms={LC={capacity=40,membersOnly=false}},
  build={buildId="testbuild"},
  onConnect=function()error("bad initialization")end,
  onPacket=function(peer,name)
    if peer.id=="bad" then error("malformed spawn username")end
    received=received+1
  end,
  onClose=function()disconnected=disconnected+1 end
})
local function mock(id,decode,recv)
  local item={id=id,state="websocket",closed=false,upgraded=true,
    ip="127.0.0.1",roomKey="LC",
    input=Frames.clientFrame("client-packet",2,"abcd"),out="",
    session={decode=decode or function()
      return {name="M",args={}}
    end}}
  item.tcp={send=function(_,out)return #out end,
    receive=recv or function()return nil,"timeout",""end,
    close=function()end,
    getpeername=function()return "127.0.0.1" end}
  return item
end
local bad=mock("bad")
local good=mock("good")
room.listener={accept=function()return nil end}
room.active=2
room.activeByIp["127.0.0.1"]=2
room.activeByRoom.LC=2
room.peers={bad,good}
room:update()
assert(bad.closed and not good.closed,
  "A bad player's packet disconnected everyone")
assert(received==1 and #room.peers==1 and room.peers[1]==good,
  "Room did not process the healthy player after rejected frame")
assert(room.peerFailures==1 and room.lastPeerFailure:find("onPacket",1,true),
  "Offender was not recorded and rejected")
assert(room.active==1 and disconnected==1,
  "Failed peer did not release its room slot")

local anti=mock("bad",function()return nil,"tampered MAC"end)
anti.player={anticheat={onTransportError=function()error("callback failed")end}}
room.active=2
room.activeByIp["127.0.0.1"]=2
room.activeByRoom.LC=2
room.peers={anti,good}
good.input=Frames.clientFrame("ok",2,"abcd")
room:update()
assert(anti.closed and not good.closed and received==2,
  "Anticheat callback could terminate unrelated player sessions")
assert(room.peerFailures==2 and
  room.lastPeerFailure:find("packetDecode",1,true))

local broken=mock("bad",nil,function()error("broken socket")end)
room.active=2
room.activeByIp["127.0.0.1"]=2
room.activeByRoom.LC=2
room.peers={broken,good}
good.input=Frames.clientFrame("ok",2,"abcd")
room:update()
assert(broken.closed and not good.closed and received==3,
  "Socket callback error terminated another player")
assert(room.lastPeerFailure:find("network",1,true))
room.api={handle=function()error("malformed API JSON")end}
local http={state="http",closed=false,out="",
  tcp={close=function()end,getpeername=function()return "127.0.0.1"end}}
room:request(http,{
  method="POST",target="/api/login",body="{broken",
  headers={}
})
assert(http.closed and room.lastPeerFailure:find("api",1,true),
  "Malformed API request should not crash the room")
assert(room.listener and not good.closed)
room:close()
print("ANDROID LUA PEER ISOLATION PASS: invalid spawn/MAC/network/API contained")
