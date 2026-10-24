-- SPDX-License-Identifier: AGPL-3.0-only
-- Adapter smoke: genuine Room.bindPlayer/handleInput and Host callbacks.
-- No client-facing replacement Player class is shipped by this fixture.
local Room=require("server-lua.world.room")
local Transport=require("server-lua.net.room_transport")
local Host=require("server-lua.net.host")
local Pack=require("src.protocol.msgpack")
local items={
 weapons={[0]={id=0,gather=1,range=65,dmg=25,speed=300}},
 projectiles={[0]={range=1000,speed=1.6,dmg=25,scale=103,layer=0}},
 list={[3]={id=3}}
}
local events={}
local room=Room.new({
 nowMs=10000,items=items,services={ensureAnimals=function()end}
})
local pcount=0
local bridge=Transport.new({
 room=room,
 createPlayer=function(peer,ticket)
   pcount=pcount+1
   local player={
     id="client-"..ticket.did,sid=pcount,alive=true,active=true,
     dir=0,moveDir=0,pingCooldown=0,
     weaponIndex=0,buildIndex=-1,mouseState=0,hits=0,
     send=function()return true end,
     variant=function()return {id=0,val=1}end,
     canSee=function()return true end,
     gather=function()end,
     changeHealth=function()end,
     addResource=function()end,
     shootTurret=function()end
   }
   return player
 end,
 onJoined=function(player,peer)
   events[#events+1]="joined"
   assert(player.id=="client-testdid")
   player:send("A",{teams={},animals={}})
 end,
 onDisconnect=function(player)
   events[#events+1]="disconnected"
   assert(player.sid==1)
 end
})
local callbacks=bridge:callbacks()
assert(type(callbacks.onConnect)=="function"
   and type(callbacks.onPacket)=="function"
   and type(callbacks.onClose)=="function")
-- Host accepts exactly the same callbacks without opening a socket.
local host=Host.new({
 bind="127.0.0.1",port=18944,roomCode="testing42",
 onConnect=callbacks.onConnect,onPacket=callbacks.onPacket,
 onClose=callbacks.onClose
})
assert(host and not host.listener,"do not launch a production listener in smoke")
local peer={closed=false,sent={}}
peer.send=function(self,name,args)
 self.sent[#self.sent+1]={name=name,args=args}
 return true
end
callbacks.onConnect(peer,{did="testdid"})
assert(#room.players==1 and peer.player==room.players[1])
assert(peer.sent[1].name=="A","original welcome callback emitted A")
assert(#peer.sent[1].args==1,"welcome packed as one payload object")
callbacks.onPacket(peer,"D",{1.2})
assert(room.players[1].dir==1.2,"aim packet reached original Room.input")
callbacks.onPacket(peer,"9",{2.4})
assert(room.players[1].moveDir==2.4)
room.players[1]:send("a",1,nil,3)
local args=peer.sent[#peer.sent].args
assert(#args==3 and args[1]==1 and args[2]==Pack.null and args[3]==3,
  "nil must keep its MessagePack array position")
local rogue={closed=false}
assert(not pcall(callbacks.onPacket,rogue,"D",{0.8}),
  "unknown peer must not control a room player")
assert(not pcall(callbacks.onConnect,peer,{did="testdid"}),
  "one peer must not create duplicate players")
assert(callbacks.onClose(peer)==true)
assert(#room.players==0 and peer.player==nil)
assert(callbacks.onClose(peer)==false,"double disconnect must not rerun cleanup")
assert(not pcall(callbacks.onPacket,peer,"D",{0.8}),
  "closed session cannot issue commands")
assert(events[1]=="joined" and events[2]=="disconnected"
  and #events==2,"exactly once lifecycle")
print("PASS Host callbacks -> Room bind/input, authenticated one-use identity")
print("PASS room cleanup, closed-session rejection, welcome and nullable packets")
