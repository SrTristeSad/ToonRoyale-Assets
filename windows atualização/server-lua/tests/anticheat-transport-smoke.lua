-- SPDX-License-Identifier: AGPL-3.0-only
-- Native AntiCheat -> real PlayerRegistry -> authenticated RoomTransport.
-- No noop anticheat in this test: Node-compatible token buckets are exercised.
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local Transport=require("server-lua.net.room_transport")
local Anticheat=require("server-lua.anticheat.index")
local time=100000
local logs={}
local function append(v)logs[#logs+1]=v end
local room=Room.new({nowMs=10000,services={ensureAnimals=function()end}})
local seq=0
local registry=Registry.new(room,{
 randomString=function(size)
   assert(size==16)
   seq=seq+1
   return ("%016d"):format(seq)
 end,
 nowMs=function()return time end,
 randomSalt=function()return 397840974 end,
 log=function(p,msg)append("LOG:"..p.sid..":"..msg)end,
 kickPeer=function(peer,reason)
   append("KICK:"..reason)
   peer.closed=true
 end,
 closePeer=function(peer,code)
   append("CLOSE:"..code)
   peer.closed=true
 end,
 onDeath=function()end,
 clanList=function()return {}end,
 recordLife=function()end,
 leaveTribe=function()end,
 forget=function()end,
 removeItems=function()end
})
local bridge=Transport.new(registry:transportOptions())
local function newPeer()
 local peer={
  ip="127.0.0.1",closed=false,sent={},
  session={pinned=true,sealMode=1,sealReport="seal",
   lastSeq=5,ledgerBefore=100}
 }
 peer.send=function(self,name,args)
   self.sent[#self.sent+1]={name=name,args=args}
   return true
 end
 return peer
end
local peer=newPeer()
local player=bridge:connected(peer,{did="fixture"})
assert(player.anticheat and getmetatable(player.anticheat)==Anticheat)
assert(player.anticheat.player==player,"anticheat bound to real Player, not temporary fake")
assert(player.anticheat.session==peer.session,"real ProtocolSession must be shared")
assert(player.skins[51]==1 and player.skins[45]==nil,"original store default applied")
assert(#room.players==1)
assert(player.did=="fixture","ticket DID available to native penalty lock")
bridge:packet(peer,"M",{{name="Hero"}})
assert(player.alive and player.name=="Hero","original spawn command")
local allowed,denied=0,0
for i=1,72 do
 local result=bridge:packet(peer,"D",{i})
 if result==false then denied=denied+1 else allowed=allowed+1 end
end
assert(allowed==70 and denied==2,"original D packet burst 70; 2 must drop")
assert(player.dir==70,"blocked packets must NEVER reach Player direction")
assert(player.anticheat.strikes==2,"original anticheat violation accounting")
-- The original telemetry challenge is sent at 30 seconds after spawn;
-- use a deterministic cryptographic-salt fixture, not a production bypass.
time=130000
player.anticheat:tick(time)
local probe=peer.sent[#peer.sent]
assert(probe.name=="q" and probe.args[1]==397840974
 and type(probe.args[2])=="table" and #probe.args[2]==0,
 "the empty-probes LAN policy still requires a random challenge")
time=130010
player.anticheat:onTelemetry({0,0,0,"seal",397840974,4,100})
assert(player.anticheat.answered==1 and player.anticheat.pending==nil,
 "authenticated telemetry response accepted")
-- An unknown decoded transport packet is a protocol violation: no parsing
-- command can reach room after the anti-cheat closes this peer.
player.anticheat:onTransportError("bad tag","invalid frame")
assert(peer.closed and player.anticheat.closed)
assert(not pcall(function()bridge:packet(peer,"D",{1})end),
 "peer closed by HMAC failure must be rejected")
assert(bridge:closed(peer) and #room.players==0)
assert(logs[#logs]=="CLOSE:4001","original close code required")
print("PASS Native AntiCheat -> Registry -> RoomTransport: 70 accepted, 2 dropped")
print("PASS telemetry q/T, HMAC failure close 4001 and disconnected Player")
