-- SPDX-License-Identifier: AGPL-3.0-only
-- Cross-module progression test with REAL Room/Player/Registry/Transport,
-- native TribeManager, input packets H/c/L/b/P/Q/N/6, physics and network.
-- Test-only stubs for still-unported account/persistence are explicit;
-- this is NOT evidence that all production services are complete.
local Room=require("server-lua.world.room")
local Registry=require("server-lua.world.player_registry")
local Transport=require("server-lua.net.room_transport")
local Cat=require("server-lua.world.catalogue")
local events={}
local function emit(packet,...)
 local args={...}
 events[#events+1]={packet=packet,args=args}
end
local room=Room.new({
 nowMs=10000,items=Cat,
 services={ensureAnimals=function()end},
 broadcast=emit,
 chat={gameChat=function(_,player,msg,key)
   assert(key=="LC" and player.sid>=0)
   events[#events+1]={packet="LOG",args={player.sid,msg}}
 end}
})
assert(room.tribes and #room.tribes:list()==0)
local sequence=0
local registry=Registry.new(room,{
 randomString=function(n)
   assert(n==16)
   sequence=sequence+1
   return string.format("%016d",sequence)
 end,
 anticheatFactory=function()
   return {
     allow=function()return true end,
     invalid=function(_,name,why)error(name..":"..why)end,
     onGameStart=function()end,tick=function()end,
   }
 end,
 onDeath=function()end,
 recordLife=function()end,
 removeItems=function()end,
 -- clanList/leaveTribe/forget all route to the native TribeManager.
})
local bridge=Transport.new(registry:transportOptions())
local function join(did)
 local peer={ip="127.0.0.1",closed=false,sent={},session={}}
 peer.send=function(self,packet,args)
   self.sent[#self.sent+1]={packet=packet,args=args}
   return true
 end
 local player=bridge:connected(peer,{did=did})
 return peer,player
end
local a,owner=join("111aaa")
local b,guest=join("222bbb")
assert(owner.sid==0 and guest.sid==1 and #room.players==2)
assert(a.sent[1].packet=="A" and b.sent[1].packet=="A")
bridge:packet(a,"M",{{name="Owner",skin=0}})
bridge:packet(b,"M",{{name="Guest",skin=0}})
assert(owner.alive and guest.alive)
assert(owner.name=="Owner" and guest.name=="Guest")
-- Upgrade is age 2 by default and the original catalogue grants the axe.
owner.upgradePoints=1
bridge:packet(a,"H",{1})
assert(owner.weapons[1]==1 and owner.weaponIndex==1)
assert(owner.upgradePoints==0 and owner.upgrAge==3)
-- Store purchase uses the original hat id 57 / 50 points.
owner.points=800
bridge:packet(a,"c",{1,57,0})
assert(owner.skins[57]==1 and owner.points==750)
bridge:packet(a,"c",{0,57,0})
assert(owner.skinIndex==57 and owner.skin.id==57)
bridge:packet(a,"c",{0,0,0})
assert(owner.skinIndex==0 and owner.skin==nil)
bridge:packet(a,"L",{"Alpha"})
assert(owner.team=="Alpha" and owner.isOwner)
assert(#room.tribes:list()==1 and room.tribes:list()[1].sid=="Alpha")
bridge:packet(b,"b",{"Alpha"})
assert(owner.joinRequests[guest.sid]==true,"original join request reached owner")
bridge:packet(a,"P",{guest.sid,true})
assert(guest.team=="Alpha" and not guest.isOwner)
bridge:packet(a,"Q",{guest.sid})
assert(guest.team==nil)
owner.tribeCooldown=0
bridge:packet(a,"N",{})
assert(owner.team==nil and #room.tribes:list()==0)
bridge:packet(b,"6",{"Hello Moo!"})
assert(guest.chatCooldown==room.config.chatCooldown)
local found={A=0,C=0,V=0,U=0,["5"]=0,g=0,["2"]=0,
 ["3"]=0,["4"]=0,["1"]=0,["6"]=0}
for _,peer in ipairs({a,b}) do
 for _,message in ipairs(peer.sent) do
   if found[message.packet]~=nil then
     found[message.packet]=found[message.packet]+1
   end
 end
end
for _,message in ipairs(events) do
 if found[message.packet]~=nil then found[message.packet]=found[message.packet]+1 end
end
for packet,count in pairs(found) do
 assert(count>0,"original packet missing: "..packet)
end
room:tick(10100)
assert(owner.alive and guest.alive,"both players playable for a physics tick")
assert(bridge:closed(b) and bridge:closed(a))
assert(#room.players==0,"both sessions removed")
assert(#room.tribes:list()==0,"no orphan tribes after disconnect")
print("PASS two real Players: guest spawn, age upgrade, purchase/equip hat")
print("PASS original tribe create/request/accept/kick/dissolve + chat + Game.tick")
print("PASS native RoomTransport cleanup, all 11 packet types delivered")
